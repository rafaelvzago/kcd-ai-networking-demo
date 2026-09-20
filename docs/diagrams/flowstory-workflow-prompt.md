# Reusable FlowStory Workflow Prompt

Read the FlowStory guide at `<FLOWSTORY_GUIDE_URL>` and the example at `<FLOWSTORY_EXAMPLE_URL>`.

Create a single self-contained HTML file at `<OUTPUT_PATH>` that:

- loads CSS from `https://noyitz.github.io/flowstory/templates/style.css`;
- imports FlowStory from `https://noyitz.github.io/flowstory/src/index.js`;
- embeds the diagram JSON inline as `const diagram = { ... }` and loads it with `await viz.load(diagram)`;
- auto-plays with loop mode enabled on load;
- has no separate diagram JSON file or new dependency.

Research the supplied architecture sources before drawing. Use the diagram to explain this workflow:

1. An **Application Pod** inside a clearly labeled Kubernetes cluster sends a request to an internal Gateway.
2. The Gateway has a Cluster-routable address (`routability: Cluster`).
3. An attached HTTPRoute matches the request. Its node must visibly name the relation to its Backend, for example `backendRef: <backend-name>`.
4. The HTTPRoute enriches the request with the specified headers.
5. A Kubernetes `Backend` resource represents the external destination using the proposal’s appropriate external-hostname mechanism.
6. The Backend sends the external TLS call to `<external-host>:443` and the response returns all the way to the Pod.

Use presentation-friendly visual conventions:

- Keep all Kubernetes resources inside the cluster boundary and the external endpoint outside it.
- Use blue for in-cluster request routing, orange for request-header enrichment, purple only for the external endpoint and its outbound TLS hop, and green for responses.
- Keep labels short enough to fit inside their nodes.
- Add a retractable sidebar button that expands the canvas when closed.
- Use a native speed dropdown with 1×, 2×, and 4×; start playback at 2×.

Make every Kubernetes resource node clickable. Its dialog must show readable, illustrative YAML matching the diagram:

- Show Pod, Gateway, HTTPRoute, and Backend manifests.
- Put request-header filters in the HTTPRoute manifest, rather than inventing a standalone resource for the filter.
- Explain that the external endpoint has no Kubernetes manifest.
- Label proposed or experimental API fields as illustrative where appropriate.
- Make the dialog slide-ready: large (up to about 900px), readable text, syntax-highlighted YAML, and correct dark/light theme contrast.
- Ensure the dialog is above the selected-node highlight; the highlight may remain dimly visible behind it.

Validate the HTML in a browser after generating it. Keep the implementation minimal: use FlowStory’s existing controls and a small local enhancement only where the hosted library does not provide the required behavior.
