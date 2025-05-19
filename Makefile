.PHONY: build test test-file shell update all

# Docker image name
IMAGE_NAME = openc_bot_test

# Project directory (to be mounted in container)
PROJECT_DIR = $(shell pwd)

# SSH mount argument - simple version that just mounts .ssh directory
SSH_MOUNT_ARGS = -v $(HOME)/.ssh:/root/.ssh:ro

# Default target
all: test

# Build Docker image with Ruby 2.6.3
build:
	@echo "Building Docker image with Ruby 2.6.3..."
	docker build -t $(IMAGE_NAME) -f Dockerfile .

# Update dependencies in the Docker container
update:
	@echo "Updating dependencies in Docker container..."
	docker run --rm \
		-v $(PROJECT_DIR):/app \
		$(SSH_MOUNT_ARGS) \
		$(IMAGE_NAME) bash -c "bundle update"

# Run tests in the Docker container
test: build
	@echo "Running tests in Docker container..."
	docker run --rm \
		-v $(PROJECT_DIR):/app \
		$(SSH_MOUNT_ARGS) \
		$(IMAGE_NAME) bash -c "bundle update && bundle install && bundle exec rspec"

# Run a specific test file
test-file: build
	@echo "Running test file: $(FILE)"
	docker run --rm \
		-v $(PROJECT_DIR):/app \
		$(SSH_MOUNT_ARGS) \
		$(IMAGE_NAME) bash -c "bundle update && bundle install && bundle exec rspec $(FILE)"

# Open a shell in the Docker container
shell: build
	@echo "Opening shell in Docker container..."
	docker run --rm -it \
		-v $(PROJECT_DIR):/app \
		$(SSH_MOUNT_ARGS) \
		$(IMAGE_NAME) bash -c "bundle install && bash"

# Start a Ruby console in the Docker container
console: build
	@echo "Starting IRB in Docker container..."
	docker run --rm -it \
		-v $(PROJECT_DIR):/app \
		$(SSH_MOUNT_ARGS) \
		$(IMAGE_NAME) bash -c "bundle update && bundle install && bundle exec irb -r ./lib/openc_bot.rb"

# Clean up Docker images
clean:
	@echo "Removing Docker image..."
	-docker rmi $(IMAGE_NAME)

# Run a custom command in the Docker container
# Usage: make run CMD="bundle exec rake some_task"
run: build
	@echo "Running command: $(CMD)"
	docker run --rm \
		-v $(PROJECT_DIR):/app \
		$(SSH_MOUNT_ARGS) \
		$(IMAGE_NAME) bash -c "bundle update && bundle install && $(CMD)"

# Help target
help:
	@echo "Available targets:"
	@echo "  make build    - Build the Docker image with Ruby 2.6.3"
	@echo "  make test     - Run all tests in the Docker container"
	@echo "  make test-file FILE=path/to/test.rb - Run a specific test file"
	@echo "  make shell    - Open a shell in the Docker container"
	@echo "  make console  - Start a Ruby console with openc_bot loaded"
	@echo "  make run CMD=\"command\" - Run a custom command in the container"
	@echo "  make clean    - Remove the Docker image"
