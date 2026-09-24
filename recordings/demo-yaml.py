"""Show only the live Kubernetes fields used in the demo (requires PyYAML)."""

import sys

import yaml


for item in yaml.safe_load(sys.stdin)["items"]:
    metadata = {key: item["metadata"][key] for key in ("name", "namespace")}
    spec = item["spec"]
    if item["kind"] == "Pod":
        metadata["labels"] = {"app": item["metadata"]["labels"]["app"]}
        spec = {
            "containers": [
                {key: container[key] for key in ("name", "image", "args", "ports") if key in container}
                for container in spec["containers"]
            ]
        }
    yaml.safe_dump(
        {"apiVersion": item["apiVersion"], "kind": item["kind"], "metadata": metadata, "spec": spec},
        sys.stdout,
        sort_keys=False,
        explicit_start=True,
    )
