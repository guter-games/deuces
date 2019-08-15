.PHONY: start stop restart up-server up-web up-postgres ssh logs

# Start all services
start: | up-web up-server up-postgres

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

# Start the postgres container
up-postgres:
	@docker-compose up -d postgres

# Clears the build cache and rebuilds the container
build-server-fresh:
	@docker-compose build --no-cache server

# Clears the build cache and rebuilds the container
build-web-fresh:
	@docker-compose build --no-cache web

# Clears the build cache and rebuilds the container
build-postgres-fresh:
	@docker-compose build --no-cache postgres

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

# Enter Postgres console
psql:
	@docker exec -it deuces-postgres psql -U deuces_dev deuces