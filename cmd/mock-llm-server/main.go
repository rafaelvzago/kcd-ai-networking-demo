package main

import (
	"container/list"
	"crypto/subtle"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"
)

const completionTokens = 12

type message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type completionRequest struct {
	Model       string    `json:"model"`
	Messages    []message `json:"messages"`
	DelayMS     *int      `json:"simulate_delay_ms,omitempty"`
	CacheStatus *string   `json:"cache_status,omitempty"`
}

type cache struct {
	mu      sync.Mutex
	entries map[string]*list.Element
	order   *list.List
}

func newCache() *cache {
	return &cache{entries: make(map[string]*list.Element), order: list.New()}
}

func (c *cache) seen(key string) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	if entry, ok := c.entries[key]; ok {
		c.order.MoveToFront(entry)
		return true
	}
	entry := c.order.PushFront(key)
	c.entries[key] = entry
	if c.order.Len() > 1000 {
		last := c.order.Back()
		delete(c.entries, last.Value.(string))
		c.order.Remove(last)
	}
	return false
}

func newHandler(instance, apiKey string) http.Handler {
	cachedPrompts := newCache()
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	mux.HandleFunc("POST /v1/chat/completions", func(w http.ResponseWriter, r *http.Request) {
		if apiKey != "" && subtle.ConstantTimeCompare([]byte(r.Header.Get("Authorization")), []byte("Bearer "+apiKey)) != 1 {
			writeError(w, http.StatusUnauthorized, "invalid_api_key", "missing or invalid authorization")
			return
		}
		var request completionRequest
		decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<20))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&request); err != nil || request.Model == "" || len(request.Messages) == 0 {
			writeError(w, http.StatusBadRequest, "invalid_request_error", "model and messages are required")
			return
		}
		delay, cacheStatus, err := simulation(r, request)
		if err != nil {
			writeError(w, http.StatusBadRequest, "invalid_request_error", err.Error())
			return
		}
		if delay > 0 {
			time.Sleep(time.Duration(delay) * time.Millisecond)
		}
		key, _ := json.Marshal(struct {
			Model    string    `json:"model"`
			Messages []message `json:"messages"`
		}{request.Model, request.Messages})
		if cacheStatus == "" {
			cacheStatus = "MISS"
			if cachedPrompts.seen(string(key)) {
				cacheStatus = "HIT"
			}
		}
		promptTokens := 0
		for _, message := range request.Messages {
			promptTokens += len(strings.Fields(message.Content))
		}
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("X-Cache-Status", cacheStatus)
		w.Header().Set("X-Instance-Name", instance)
		json.NewEncoder(w).Encode(map[string]any{
			"id":       fmt.Sprintf("chatcmpl-%d", time.Now().UnixNano()),
			"object":   "chat.completion",
			"created":  time.Now().Unix(),
			"model":    request.Model,
			"instance": instance,
			"choices":  []map[string]any{{"index": 0, "message": map[string]string{"role": "assistant", "content": "Mock response from " + instance}, "finish_reason": "stop"}},
			"usage":    map[string]int{"prompt_tokens": promptTokens, "completion_tokens": completionTokens, "total_tokens": promptTokens + completionTokens},
		})
	})
	return mux
}

func simulation(r *http.Request, request completionRequest) (int, string, error) {
	delay, status := 0, ""
	if header := r.Header.Get("X-Simulate-Delay-MS"); header != "" {
		value, err := strconv.Atoi(header)
		if err != nil {
			return 0, "", fmt.Errorf("X-Simulate-Delay-MS must be an integer")
		}
		delay = value
	}
	if header := r.Header.Get("X-Cache-Status"); header != "" {
		status = header
	}
	if request.DelayMS != nil {
		delay = *request.DelayMS
	}
	if request.CacheStatus != nil {
		status = *request.CacheStatus
	}
	if delay < 0 || delay > 10000 {
		return 0, "", fmt.Errorf("delay must be between 0 and 10000 ms")
	}
	if status != "" && status != "HIT" && status != "MISS" {
		return 0, "", fmt.Errorf("cache status must be HIT or MISS")
	}
	return delay, status, nil
}

func writeError(w http.ResponseWriter, status int, kind, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]any{"error": map[string]string{"message": message, "type": kind}})
}

func main() {
	instance := os.Getenv("INSTANCE_NAME")
	if instance == "" {
		instance = "mock-llm-server"
	}
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	if err := http.ListenAndServe(":"+port, newHandler(instance, os.Getenv("REQUIRED_API_KEY"))); err != nil {
		panic(err)
	}
}
