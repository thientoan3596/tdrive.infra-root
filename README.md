# TDRIVE Microserivce Project

This project act as a sample of spring microservice.
Tdrive mimics the behavior of Google, with a focus on two main downstream services: Storage (for file saving) and Security (for user management), along with essential services like API Gateway (Cloud Gateway) and Service Registry (Eureka). The goal is to create a basic, simplified version of Google's microservices architecture.

## Services

### Storage Service

- Handling file saving and retrieval.
- Create mapping between actual file on system and database record (using uuid)
- Folder/directory is being created on system, instead creating database record.
- **Path**: /storage/v1/

### Security Service

- Manage user authentication and authorization (with JWT).
- **Path**: /auth/v1/

### API Gateway (Spring Cloud Gateway)

- Acts as a single entry point for all client requests.
- Routes requests to the appropriate downstream services (Storage and Security).

### Service Registry (Eureka)

- Provides service discovery, allowing services to find and communicate with each other.

## Technologies Used

1. Spring Boot for backend services.
2. Eureka for service registry and discovery.
3. Spring Cloud Gateway for the API gateway.
4. JWT for user authentication in Security service.
5. Sprindoc for api documentation.
6. MySQL (8.0) for databases.

## Running the Project

### Prerequisites:

- **Java:** Version 17 or higher is required to use this library.
- **Docker:** Required for containerization and running the service locally or in a Docker Compose setup.
- **openssl:** Required for automatically generate jwt secure.

### Getting Started

1. Clone the repository:

```bash
git clone --recursive <repo-url>
```

2. Generating default .env:

```bash
cp .env.example .env
```

3. Build and Run container using docker-compose:

```bash
./pre-start.sh -v
```

## Features:

### Actuator:

Spring Actuator is included (i.e., health, env) and PUBLICLY AVAILABLE to all user.
To access those actuator, using `<host-name>:<port>/<service-name>/<version>/actuator/{endpoint}`.

For example: http://localhost:8080/auth/v1/actuator/env.

For security reason, the env actuator should be secured, (health endpoint can be public and should be for using docker compose health check).
By default, secured actuators need `ROLE_SYSTEM_ADMIN` authorization.
To secure actuator endpoints, please adding following to `.env`:

```bash
SECURITY_MS_SECURE_ACTUATORS=/actuator/env,/actuator/health
```

And adding to [docker-compose.yml](docker-compose.yml) with target service:

```yml
security-ms:
  environment:
    SECURE_ACTUATORS: ${SECURE_ACTUATORS}
```

> **_NOTE:_** The path should be service relative!

### Springdoc (Swagger):

Springdoc (Swagger) is also included, and PUBLICLY AVAILABLE to everyone.
Springdoc is accessible at http:/localhost:8080/swagger-ui.html.
Springdoc is centrally collected at `api-gateway` service. ([see](https://github.com/piomin/sample-spring-microservices-new) for more detail).
**TL;DR**
`api-gateway` will used defined `RouteDefinitionLocator` to scan and construct list of SwaggerUrl definition.
Rewrite incoming request /v3/api-docs/(<path>) to (<path>).

## Note

If you are facing issue with loading .env when manually run the project (locally),
especiall within multiplexer, consider using:

```bash
set -a
. .env
set +a
```

## Future Considerations:

Considerations for future update:

### Enhencement:

- Spring Cloud Config Server: Centralize configuration with `Spring Cloud Config`.

### Test:

- Should include test.
