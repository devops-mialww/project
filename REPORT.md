# Infrastructure as Code, CI/CD and Drift Detection

- Miami Alvelistin (miami@kth.se)
- Albin Wallenius Woxnerud (alww@kth.se)

## Architecture and processes

The infrastructure is defined as code using Terraform and the Docker provider. Terraform declares three main resources: the application image, built from the repository's Dockerfile; a named volume for the SQLite database; and the application container. The container runs as a non-root user (UID 31337), uses a read-only root filesystem, is limited to 256 MB of memory with swap disabled, has all Linux capabilities dropped, and uses `no-new-privileges`. It is published only on the loopback interface. The database is stored in `/app/data` on a separate volume, allowing the rest of the container filesystem to remain read-only while preserving data across redeployments.

Changes are submitted through pull requests and must pass the project's CI checks before deployment. The CI pipeline runs on GitHub-hosted runners with read-only repository access. Its jobs include running the test suite with pytest, building the Docker image, and scanning the Dockerfile and Terraform configuration with Checkov. Dependabot also creates pull requests for dependency updates and published CVEs, which go through the same validation process.

Once CI succeeds for a push to `main`, the CD workflow runs on a self-hosted runner. It executes `terraform apply` using the commit SHA as the image tag, records the deployed SHA, and calls the API's health endpoint as a smoke test. Terraform therefore manages both building the image and deploying the resulting container, without requiring a separate image registry.

A separate drift-detection workflow runs hourly. It checks out the commit that is currently deployed and executes `terraform plan -detailed-exitcode`. If the plan detects a change, the running infrastructure no longer matches the declared configuration. This was verified experimentally by increasing the container's memory limit with `docker update`. The subsequent drift check detected the change, and a later CD run restored the declared value. The following drift check then passed. Drift detection and CD use the same concurrency group so that a plan cannot run while an apply is in progress.

## Design decisions

**Poetry and Python 3.14.** Poetry was retained for its lockfile and Dependabot integration despite a conflicting `requirements.txt`. The Python 3.14 upgrade also required replacing `sqlalchemy-utils` with SQLAlchemy's built-in `Uuid` type.

**Two-stage Docker build.** A two-stage build keeps Poetry and test dependencies out of the final image, reducing its attack surface. The container runs as UID 31337, while `/app/data` is kept on a separate volume so the root filesystem can remain read-only.

**Terraform and the Docker provider.** The Docker provider was chosen to demonstrate Terraform's plan/apply/state workflow without requiring cloud infrastructure, credentials, or additional services.

**Terraform builds the image.** Terraform builds the application image as part of `terraform apply`, so a separate image registry is unnecessary. The image is tagged with the commit SHA, making deployed images traceable to the exact source commit and causing a new image to be built for each newly deployed commit.

**Terraform state.** State is stored on the runner outside the checkout because the workflow cleans untracked files before each job. A remote backend would be more robust but would add another service to the single-host setup.

**Deployment target and deployed version.** Drift detection uses the deployed commit rather than `main`, ensuring that undeployed changes cannot be mistaken for infrastructure drift.

**Detection without automatic repair.** Drift is reported rather than automatically repaired because a manual change may be intentional or an emergency fix and should be reviewed before being overwritten.

**Checkov policies.** Checkov was chosen because it scans both Dockerfiles and Terraform and supports custom YAML policies. Testing showed that its built-in checks did not cover the required Docker-provider settings, so seven custom policies were added for requirements such as non-root execution, a read-only filesystem, memory limits, and dropped capabilities. The policies are tested against both secure and intentionally insecure configurations.

**Implementation issues.** Testing revealed that Docker implicitly allows swap in addition to the configured memory limit when no swap limit is specified. This caused Terraform to report drift immediately after a fresh deployment because the effective value differed from the declared configuration. Explicitly disabling swap removed the false positive. Another implementation constraint was that the repository only permits GitHub-owned Actions, so the workflows download a pinned Terraform release instead of using HashiCorp's setup action.

## Component interaction

CI validates changes before deployment: pytest checks the application, Docker builds the image, and Checkov validates the infrastructure and security configuration. Dependabot updates follow the same path.

Terraform connects CI and CD: the same `docker_container` resource checked by Checkov is later applied by CD. Thus, security requirements such as non-root execution, a read-only filesystem, resource limits, and dropped capabilities are checked before deployment. CD then builds and deploys the image using the commit SHA and verifies it through the health endpoint.

Drift detection uses the deployed SHA to compare the running infrastructure with the configuration that produced it. Manual changes to tracked resources are therefore detected without confusing undeployed changes on `main` with drift. CD and drift detection share a concurrency group so that a plan cannot run during an apply.

The image and Terraform configuration also share a small contract: the application listens on port 8000, uses UID 31337, and stores persistent data at `/app/data`. This keeps the interface between the image and infrastructure explicit and limited.

## Limitations and trade-offs

The deployment runs on a laptop running Ubuntu under WSL2. Consequently, CD and drift detection only operate while the laptop is powered on. Although drift detection is configured to run hourly, a manual change can therefore remain undetected if the machine is unavailable.

The self-hosted runner also introduces a security trade-off. The repository is kept private because allowing untrusted pull requests from forks to execute code on a machine that hosts the deployment would create a significant risk. GitHub's limitations for branch protection on private repositories under the current plan mean that requiring changes to go through pull requests is a convention rather than an enforced repository rule.

There is no automatic rollback. If the post-deployment smoke test fails, the CD workflow is marked as failed, but the newly deployed container remains in place. Replacing the container also introduces a short period of downtime because the old container is removed before the new one starts. A more sophisticated deployment strategy could reduce or eliminate this downtime.

The drift detection is limited to resources and properties tracked by the Docker provider. Changes to the contents of the SQLite volume are not detected, even though they can affect the application's state. The Terraform state is also stored only on the deployment runner and has no backup, making loss of the runner a potential loss of state.

The security scanning has further limitations. The custom Checkov policies currently cover `docker_container`, rather than every possible infrastructure resource. CI verifies that the image can be built but does not run the image as part of the pipeline. The operating-system packages in the base image are also not scanned; a tool such as Trivy could provide additional vulnerability scanning. Furthermore, the base-image tag and GitHub Actions versions can change over time, so the build is not completely reproducible. Terraform itself is manually pinned because Dependabot does not update the downloaded Terraform version.

Finally, the use of SQLite is appropriate for this demonstration and single-host deployment but does not scale well to a production workload requiring concurrent access, high availability, or independent database scaling. The Docker provider similarly trades the operational capabilities of a cloud environment for a simpler setup with no cloud account, credentials, or additional infrastructure.

Overall, the system provides a complete infrastructure-as-code lifecycle: CI validates changes, Terraform deploys the configuration, CD records the deployed version, and scheduled drift detection verifies that the deployed infrastructure still matches its declared configuration.
