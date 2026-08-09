.PHONY: start stop restart up-server up-web ssh logs ios-gen ios-test ios-build

# Start all services
start: | up-web up-server

# Generate / test / build the iMessage app
ios-gen:
	@cd ios && xcodegen generate

# Unit + Messages-flow e2e tests (run before device QA)
ios-test: ios-gen
	@cd ios && xcodebuild test \
		-project Deuces.xcodeproj \
		-scheme DeucesCore \
		-destination 'platform=iOS Simulator,name=iPhone 17' \
		CODE_SIGNING_ALLOWED=NO

ios-build: ios-gen
	@cd ios && xcodebuild build \
		-project Deuces.xcodeproj \
		-scheme Deuces \
		-destination 'platform=iOS Simulator,name=iPhone 17' \
		CODE_SIGNING_ALLOWED=NO

# Kill all services
stop:
	@docker-compose kill

# Restart all services
restart: | stop start

# Start the server container
up-server:
	@docker-compose up -d server

# Start the web container
up-web:
	@docker-compose up -d web

# Clears the build cache and rebuilds the container
build-server-fresh:
	@docker-compose build --no-cache server

# Clears the build cache and rebuilds the container
build-web-fresh:
	@docker-compose build --no-cache web

# SSH into a container
# EXAMPLE: make ssh tar=web
ssh:
	@docker exec -it deuces-$${tar} /bin/bash

# Live log viewer
# EXAMPLE: make logs tar=server
#		   make logs tar=web tail=10
tail = -1 # Default to showing all lines
logs:
	@docker logs -f deuces-$${tar} --tail ${tail}

# Same as "logs" but with timestamps
logst:
	@docker logs -t -f deuces-$${tar} --tail ${tail}
