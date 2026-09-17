![Example usage of Isaac Launchable](images/IsaacLaunchableDemo_GitHub_wide.gif)

# Isaac Launchable

> Fork of [isaac-sim/isaac-launchable](https://github.com/isaac-sim/isaac-launchable), trimmed to Isaac Sim only
> (no Isaac Lab, no VS Code container) plus an `asset-sync` sidecar that mirrors a workr-studio project's
> assets into `isaac-sim/scenes`. The mirroring is done by the `@workr-labs/sync` CLI; see
> `isaac-sim/.env.example` for the credentials it needs and `isaac-sim/asset-sync/run.sh` for the
> cycle it runs on.

Isaac Launchable offers a simplified approach to trying [Isaac Sim](https://github.com/isaac-sim/IsaacSim) in a web browser.

Through this project, users interact with Isaac Sim purely from a web browser tab providing the streamed user interface.

Launchables are provided by [NVIDIA Brev](https://developer.nvidia.com/brev), using this repo as a template. Launchables are preconfigured, fully optimized compute and software environments. They allow users to start projects without extensive setup or configuration.

## What this project contains
The installation steps for Isaac Lab are automated via Docker, such that it can be used locally, or be deployed on services such as NVIDIA Brev and run with cloud resources.

The project includes:
- Isaac Sim 6.0.1 container
- an Omniverse Kit App Streaming client, based on the [web-viewer-sample](https://github.com/NVIDIA-Omniverse/web-viewer-sample) project
- an `asset-sync` sidecar mirroring a workr-studio project's assets


## Quickstart Guide
This fork has no public Deploy button (it deploys your bucket's credentials, not something to hand out) — go straight to "Creating Your Own Launchable" below, then come back here for how to run Isaac Sim once it's up.

> [!IMPORTANT]
> This project is intended for learning purposes. It is not intended for production use.

> [!NOTE]
> Please note that Brev instances are pay-by-the-hour. To make the best use of credits, stop instances when they are not in use. Stopped instances have a smaller storage charge.

## Running Isaac Sim

1. Wait for the instance to be fully ready on Brev: running, built, and the setup script has completed (the first launch can take a while).
2. Open the instance's Shareable URL (or Secure Link), and append `/viewer` to it.
- Example: `ec2.something.amazonaws.com/viewer`
3. If nothing streams after a minute or two, the `isaac-sim` container's default entrypoint may not run headless-streaming mode on its own — SSH to the Brev instance and run `docker exec isaac-sim /isaac-sim/runheadless.sh` (this fork has no VS Code terminal, unlike upstream's Isaac Lab flow, so this is the one place a manual command might still be needed; confirm on first boot and drop this step from these notes if it isn't).
4. On subsequent relaunches, simply refresh the viewer tab to see the UI.
5. Assets mirrored from the project are under `/scenes/library` in the Isaac Sim Content browser. That directory is a view over the mirror in `/scenes/.assets`, rebuilt after each sync and holding only openable scene files — renditions like thumbnails stay in the mirror and out of the browser. Nothing should be written into `/scenes/.assets`: the sync CLI removes what it no longer sees upstream, and anything else there survives only by accident. This is pull-only: nothing saved locally is pushed back to workr-studio (see `isaac-sim/docker-compose.yml`'s `asset-sync` service and `isaac-sim/asset-sync/run.sh`).

> [!IMPORTANT]
> This setup is only intended to be used with one viewer instance. Please only keep one viewer tab open at a time for best results.

## Creating Your Own Launchable

If you'd like a Launchable with more compute, or other custom features, you can fork this repo and / or use this repo but configure a custom Launchable for your projects.

#### Configuring a Custom Brev Launchable

These instructions describe how to create a customized Launchable, similar to the one linked at the beginning of this guide.

1. Log in to the [Brev](https://login.brev.nvidia.com/signin) website.
2. Go to the Launchables category.
3. Click the **Create Launchable** button.
4. Choose the "I don't have any code files" option.
5. Choose **VM Mode - Basic VM with Python installed**, then click Next.
6. On the next page, add a setup script. Under the *Paste Script* tab, add this code (replace the repo URL with your fork and fill in the service-account token — see `isaac-sim/.env.example`). To find the project id, run `WORKR_TOKEN=<token> npx @workr-labs/sync projects` anywhere with node installed:
```bash
#!/bin/bash
export WORKR_TOKEN=your_service_account_bearer_token
export PROJECT_ID=your_project_id
export SYNC_VERSION=the_pinned_sync_version
git clone https://github.com/your-org/workr-isaac-sim
cd workr-isaac-sim/isaac-sim
docker compose up -d
```
7. This fork has no VS Code container, so there's no landing-page password to set — the Secure Links feature (step 10) is what gates access.

8. Click Next.
9. Under "Do you want a Jupyter Notebook experience" select "No, I don't want Jupyter".
10. Select the Secure Link tab, and add a secure link named "isaac" at port 80. 
11. Select the TCP/UDP ports tab.
12. Add rules to open the following ports for streaming:
```
1024
47998
49100
```
13. Click Next.
14. Choose your desired compute.

> [!NOTE]
> GPUs with RT cores are required for Kit App Streaming. 
> The compute specs and driver versions provided also need to be compatible with [Isaac Sim](https://docs.isaacsim.omniverse.nvidia.com/latest/installation/requirements.html). The available drivers are not exposed on this Brev page currently.

> [!IMPORTANT]
> The project is not currently compatible with Crusoe instances. AWS has been tested and is used for the example launchable.
15. Choose disk storage, then click Next.
16. Enter a name, then select **Create Launchable**

Congratulations! You now have a custom launchable.

## Using This Project Locally

This project can also be used to run a containerized version of Isaac Sim.

To use this project locally, you'll need a workstation that meets [Isaac Sim](https://docs.isaacsim.omniverse.nvidia.com/latest/installation/requirements.html)'s requirements.

1. Install the NVIDIA Container Toolkit: `sudo apt install nvidia-container-toolkit`
2. In `isaac-sim/docker-compose.yml`, change the `ENV=brev` line to `ENV=localhost`.
3. Copy `isaac-sim/.env.example` to `isaac-sim/.env` and fill in the service-account bearer token.
4. Inside the folder `isaac-sim`, run `docker compose up -d`.
5. Access the viewer at `localhost/viewer` in a browser.

## Troubleshooting
If you run into issues or can't make the web viewer connect, the first thing to check is that all containers are running.
If using Brev, view your GPU Instance page and find the command to open a terminal on your instance.
Once you have a terminal to the instance running the containers, run `docker ps` and note if the following containers are running:
- isaac-sim
- isaac-sim-nginx-1
- web-viewer
- asset-sync

To restart the containers:
1. From the terminal connected to your Brev instance, run `docker compose down`
2. Now run `docker compose up -d`
3. Confirm containers mentioned above are all running using `docker ps`


## Licensing Terms

By clicking the "Deploy Launchable" button, you agree to the NVIDIA Isaac Sim Additional Software and Materials License Agreement found here https://www.nvidia.com/en-us/agreements/enterprise-software/isaac-sim-additional-software-and-materials-license/.
