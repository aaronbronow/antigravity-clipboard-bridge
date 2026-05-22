UPSTREAM_DIR ?= ../agent-bridge-clipboard

.PHONY: import-upstream test

import-upstream:
	# Assume upstream has run 'make build'
	@if [ ! -d "$(UPSTREAM_DIR)/dist/antigravity-clipboard-bridge" ]; then \
		echo "Error: $(UPSTREAM_DIR)/dist/antigravity-clipboard-bridge not found."; \
		echo "Please run 'make build' in the upstream directory first."; \
		exit 1; \
	fi
	
	# Clear existing skills and plugin.json to ensure a clean state
	rm -rf skills plugin.json
	
	# Copy the entire plugin structure directly from the upstream distribution
	cp -r $(UPSTREAM_DIR)/dist/antigravity-clipboard-bridge/skills ./
	cp $(UPSTREAM_DIR)/dist/antigravity-clipboard-bridge/plugin.json ./
	chmod +x skills/copy/copy.sh

test:
	./tests/integration.sh
