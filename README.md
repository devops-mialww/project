# User Service API Example

## Overview

This is a simple User Service CRUD (Create, Read, Update, Delete) API built with FastAPI and SQLite. The API allows you to create, read, update, and delete users. It uses Pydantic models for request and response validation and SQLAlchemy for database operations.

## Architecture
This project follows a clean architecture pattern, separating concerns to enhance maintainability and scalability. Here's a brief overview:

- API Layer (FastAPI): Handles HTTP requests and responses, routing, and interaction with the service layer.
- Service Layer: Contains business logic and communicates with the database layer.
- Database Layer (SQLite): Manages data persistence and database operations.
- Testing: Unit tests are written in Pytest to test the service layer functions.

## Getting Started

### Prerequisites and Dependencies
- Python 3.14
- FastAPI
- SQLite
- Uvicorn (for running the server)

#### Poetry

This project uses [Poetry](https://python-poetry.org/) 2.x for dependency management. 

If you're not familiar with Poetry, please follow [these instructions](https://python-poetry.org/docs/#installation) to install it.

Once you've installed Poetry, you can install the dependencies using the following command:

```shell
$ poetry install
```

Then run the below command to activate the virtual environment.

```shell
$ eval $(poetry env activate)
```

## How To Run the Server

To run the server, use the following command:

```shell
$ uvicorn app.main:app --host localhost --port 8000 --reload
```

This will spin up the server at `http://localhost:8000` with a local SQLite database `users.db`.

## API Endpoints

### Create User

- `POST /api/users/`: Create a new user.

To create a user, send a POST request to `http://localhost:8000/api/users` with the following JSON payload:

```json
{
    "first_name": "John",
    "last_name": "Doe",
    "address": "123 Fake St",
    "activated": true
}
```

As we use Pydantic models, the API will validate the request payload and return an error if the payload is invalid.

### Get Users

- `GET /api/users/`: Get all users.

To get all users, send a GET request to `http://localhost:8000/api/users`.

### Get User by ID

- `GET /api/users/{userId}/`: Get a user by ID.

To get a user by ID, send a GET request to `http://localhost:8000/api/users/{userId}`. 

If the user with the specified ID does not exist, the API will return a 404 Not Found response. The same logic is carried out for the Update and Delete endpoints.


### Update User

- `PATCH /api/users/{userId}/`: Update a user by ID.

To update a user by ID, send a PATCH request to `http://localhost:8000/api/users/{userId}` with the following JSON payload:

```json
{
    "first_name": "Jane",
    "last_name": "Doe",
    "address": "321 Fake St",
    "activated": true
}
```

### Delete User

- `DELETE /api/users/{userId}/`: Delete a user by ID.

To delete a user by ID, send a DELETE request to `http://localhost:8000/api/users/{userId}`.

## How To Run the Unit Tests
To run the Unit Tests, from the root of the repo run
```shell
$ pytest 
```

This will spin up a test database in SQLite `test_db.db`, run the tests and then tear down the database. 

You can use `pytest -v` for verbose output and `pytest -s` to disable output capture for better debugging.

## DevOps Pipeline

The application is kept simple on purpose. The work is in the pipeline around it, which checks the infrastructure code as well as the application code.

| Part | Where | What it does |
| --- | --- | --- |
| CI | `.github/workflows/ci.yml` | Runs pytest, builds the Docker image and runs Checkov on every push and pull request. |
| IaC | `terraform/` | Declares the app container, its image and its data volume with the Terraform Docker provider. |
| Security scanning | `.checkov/`, `.checkov.yaml` | Checkov scans the Dockerfile and the Terraform files, including seven custom policies for `docker_container`. |
| CD | `.github/workflows/cd.yml` | After CI succeeds on `main`, runs `terraform apply` on a self-hosted runner. |
| Drift detection | `.github/workflows/drift.yml` | Runs `terraform plan` every hour and fails if the running container differs from the code. |
| Dependencies | `.github/dependabot.yml` | Dependabot updates Python packages, GitHub Actions, the base image and the Terraform provider. |

### How To Run the Container with Terraform

You need Docker and Terraform 1.9 or newer.

```shell
$ cd terraform
$ terraform init
$ terraform apply
```

This builds the image from the `Dockerfile` and starts the container at `http://127.0.0.1:8000`. The container runs as a non-root user with a read-only root filesystem, a memory limit, no Linux capabilities and `no-new-privileges`. The SQLite database is stored in the Docker volume `fastapi-crud-data`, so it survives when the container is replaced.

Run `terraform destroy` to remove the container and the volume.

### How To Run Checkov

```shell
$ poetry install --only security
$ poetry run checkov
```

### Continuous Deployment

CD runs on a self-hosted GitHub Actions runner, so the container keeps running after the workflow ends. The runner needs Linux, Docker, `unzip`, `curl` and a directory for the Terraform state:

```shell
$ sudo mkdir -p /var/lib/fastapi-crud && sudo chown $USER /var/lib/fastapi-crud
```

The state is kept outside the repository checkout because the runner cleans the checkout on every run. Set the repository variable `STATE_DIR` to use another directory.

Each deploy tags the image with the commit SHA, applies the Terraform code and then calls `/api/healthchecker`. The self-hosted jobs only run for pushes to `main`, never for pull requests.

### Drift Detection

The drift workflow runs `terraform plan -detailed-exitcode` against the commit that was last deployed. The job fails when the plan contains a change, for example after someone edits or removes the container by hand. To try it:

```shell
$ docker update --memory 512m --memory-swap 512m fastapi-crud
```

Then start the "Drift detection" workflow from the Actions tab. It fails and shows the memory change in the plan. Run the CD workflow again to bring the container back in line with the code.
