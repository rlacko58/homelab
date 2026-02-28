# Ceres

Ceres is a [Quartz64A](https://pine64.org/devices/quartz64_model_a/) server running NixOS

## Hardware

| Component      | Specification                                      |
| -------------- | -------------------------------------------------- |
| **SoC**        | 4 x ARM Cortex A55 cores @ 2.0GHz                  |
| **GPU**        | ARM Mali G52 MP2 GPU                               |
| **Memory**     | LPDDR4 RAM 8GB                                     |
| **Storage**    | Micro SD slot, eMMC module slot, SPI Flash 128Mbit |
| **Networking** | Gigabit Ethernet                                   |

## Installation of NixOS

The NixOS image for Ceres is built using the Github Actions workflow defined in `.github/workflows/build-quartz64a-nixos-image.yml`. The workflow builds the image using the Nix expression defined in `nixos-rockchip/flake.nix` and uploads the resulting image to my Minio Server. The image can then be downloaded and flashed to an SD card or eMMC module for installation on the device.

Step by step instructions:

1. Download the latest image from the Minio Server: `https://minio.lasz.io/browser/nixos-builds/quartz64a-<run_number>/`
2. Flash the image to an SD card or eMMC module using a tool like `dd` or `balenaEtcher`.
3. Insert the SD card or eMMC module into the Quartz64A and power it on.
4. Set initial root password, retrieve the IP address, adjust the Nix configuration in the repo and deploy the configuration using `nixos-rebuild switch --flake ".#ceres" --target-host root@<IP_ADDRESS>` to set up the system initially.
5. After initial setup, you can utilize the Github Actions workflow to deploy new configurations as needed. Keep in mind, that this build doesn't update the U-Boot files, for that you'd need flash the latest image again and repeat the process.
