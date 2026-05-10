.PHONY: test test-unit test-integration test-all clean install-bash-unit

# Default test target
test: test-all

# Install bash_unit if not available
install-bash-unit:
	@echo "Installing bash_unit..."
	@if [ ! -f bash_unit ]; then \
		curl -L https://github.com/pgrange/bash_unit/raw/master/bash_unit -o bash_unit; \
		chmod +x bash_unit; \
	fi

# Run unit tests (without Docker)
test-unit: install-bash-unit
	@echo "Running unit tests..."
	@./bash_unit test_plugin_system.sh test_with_wrapper.sh test_isolated_final.sh

# Run integration tests (with Docker)
test-integration: install-bash-unit
	@echo "Running integration tests..."
	@echo "Building test image..."
	@cd .. && docker build -t oci-img-diff-test . >/dev/null 2>&1
	@./bash_unit test_integration_direct.sh test_integration_ci.sh

# Run all tests
test-all: test-unit test-integration

# Run tests with verbose output
test-verbose: install-bash-unit
	@echo "Running all tests with verbose output..."
	@./bash_unit -v test/test_functions_only.sh test/test_main_script.sh test/test_plugin_system.sh test/test_isolated_final.sh test/test_integration.sh

# Run specific test file
test-file:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=test_file.sh"; \
		exit 1; \
	fi
	@./bash_unit test/$(FILE)

# Clean up test artifacts
clean:
	@echo "Cleaning up test artifacts..."
	@rm -f bash_unit
	@rm -f *.log

# Help target
help:
	@echo "Available targets:"
	@echo "  test          - Run all tests"
	@echo "  test-unit     - Run unit tests only"
	@echo "  test-integration - Run integration tests only"
	@echo "  test-all      - Run all tests (same as test)"
	@echo "  test-verbose  - Run all tests with verbose output"
	@echo "  test-file     - Run specific test file (use FILE=filename.sh)"
	@echo "  install-bash-unit - Install bash_unit testing framework"
	@echo "  clean         - Clean up test artifacts"
	@echo "  help          - Show this help message"
