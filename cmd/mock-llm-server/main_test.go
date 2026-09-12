package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func request(t *testing.T, handler http.Handler, body string, headers map[string]string) *httptest.ResponseRecorder {
	t.Helper()
	recorder := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/v1/chat/completions", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	for name, value := range headers {
		req.Header.Set(name, value)
	}
	handler.ServeHTTP(recorder, req)
	return recorder
}

func TestChatCompletionCachesPromptAndReportsInstance(t *testing.T) {
	handler := newHandler("backend-1", "")
	body := `{"model":"demo","messages":[{"role":"user","content":"hello world"}]}`

	first := request(t, handler, body, nil)
	second := request(t, handler, body, nil)

	if first.Code != http.StatusOK || second.Code != http.StatusOK {
		t.Fatalf("statuses: %d, %d", first.Code, second.Code)
	}
	if first.Header().Get("X-Cache-Status") != "MISS" || second.Header().Get("X-Cache-Status") != "HIT" {
		t.Fatalf("cache statuses: %q, %q", first.Header().Get("X-Cache-Status"), second.Header().Get("X-Cache-Status"))
	}
	if second.Header().Get("X-Instance-Name") != "backend-1" {
		t.Fatalf("instance header = %q", second.Header().Get("X-Instance-Name"))
	}
	var response struct {
		Instance string `json:"instance"`
		Usage    struct {
			PromptTokens     int `json:"prompt_tokens"`
			CompletionTokens int `json:"completion_tokens"`
			TotalTokens      int `json:"total_tokens"`
		} `json:"usage"`
	}
	if err := json.NewDecoder(second.Body).Decode(&response); err != nil {
		t.Fatal(err)
	}
	if response.Instance != "backend-1" || response.Usage.PromptTokens != 2 || response.Usage.CompletionTokens != 12 || response.Usage.TotalTokens != 14 {
		t.Fatalf("unexpected response: %#v", response)
	}
}

func TestChatCompletionRequiresConfiguredBearerToken(t *testing.T) {
	handler := newHandler("backend-1", "demo-key")
	body := `{"model":"demo","messages":[{"role":"user","content":"hello"}]}`

	unauthorized := request(t, handler, body, nil)
	authorized := request(t, handler, body, map[string]string{"Authorization": "Bearer demo-key", "X-Cache-Status": "HIT"})

	if unauthorized.Code != http.StatusUnauthorized {
		t.Fatalf("unauthorized status = %d", unauthorized.Code)
	}
	if authorized.Code != http.StatusOK || authorized.Header().Get("X-Cache-Status") != "HIT" {
		t.Fatalf("authorized status/cache = %d/%q", authorized.Code, authorized.Header().Get("X-Cache-Status"))
	}
}

func TestChatCompletionRejectsInvalidRequest(t *testing.T) {
	handler := newHandler("backend-1", "")
	response := request(t, handler, `{"model":"","messages":[]}`, map[string]string{"X-Simulate-Delay-MS": "nope"})
	if response.Code != http.StatusBadRequest {
		t.Fatalf("status = %d", response.Code)
	}
}
