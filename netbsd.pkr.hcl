variable "os_version" {
  type = string
  description = "The version of the operating system to download and install"
}

variable "architecture" {
  type = object({
    name = string
    image = string
    qemu = string
  })
  description = "The type of CPU to use when building"
}

variable "machine_type" {
  default = "pc"
  type = string
  description = "The type of machine to use when building"
}

variable "cpu_type" {
  default = "qemu64"
  type = string
  description = "The type of CPU to use when building"
}

variable "memory" {
  default = 4096
  type = number
  description = "The amount of memory to use when building the VM in megabytes"
}

variable "cpus" {
  default = 2
  type = number
  description = "The number of cpus to use when building the VM"
}

variable "disk_size" {
  default = "12G"
  type = string
  description = "The size in bytes of the hard disk of the VM"
}

variable "checksum" {
  type = string
  description = "The checksum for the virtual hard drive file"
}

variable "root_password" {
  default = "vagrant"
  type = string
  description = "The password for the root user"
}

variable "secondary_user_password" {
  default = "vagrant"
  type = string
  description = "The password for the `secondary_user_username` user"
}

variable "secondary_user_username" {
  default = "vagrant"
  type = string
  description = "The name for the secondary user"
}

variable "headless" {
  default = false
  description = "When this value is set to `true`, the machine will start without a console"
}

variable "use_default_display" {
  default = true
  type = bool
  description = "If true, do not pass a -display option to qemu, allowing it to choose the default"
}

variable "display" {
  default = "cocoa"
  description = "What QEMU -display option to use"
}

variable "accelerator" {
  default = "tcg"
  type = string
  description = "The accelerator type to use when running the VM"
}

variable "sudo_version" {
  type = string
  description = "The version of the sudo package to install"
}

variable "rsync_version" {
  type = string
  description = "The version of the rsync package to install"
}

locals {
  iso_target_extension = "iso"
  iso_target_path = "packer_cache"
  iso_full_target_path = "${local.iso_target_path}/${sha1(var.checksum)}.${local.iso_target_extension}"

  image = "NetBSD-${var.os_version}-${var.architecture.image}.${local.iso_target_extension}"
  vm_name = "netbsd-${var.os_version}-${var.architecture.name}.qcow2"
}

source "qemu" "qemu" {
  machine_type = var.machine_type
  cpus = var.cpus
  memory = var.memory
  net_device = "virtio-net"

  disk_compression = true
  disk_interface = "virtio"
  disk_size = var.disk_size
  format = "qcow2"

  headless = var.headless
  use_default_display = var.use_default_display
  display = var.display
  accelerator = var.accelerator
  qemu_binary = "qemu-system-${var.architecture.qemu}"

  boot_wait = "1m"

  boot_command = [
    "a<enter><wait5>", // Installation messages in English
    "a<enter><wait5>", // Keyboard type: unchanged

    "a<enter><wait5>", // Install NetBSD to hard disk
    "b<enter><wait5>", // Yes

    "a<enter><wait5>", // Available disks: sd0
    "a<enter><wait5>", // Guid Partition Table
    "a<enter><wait5>", // This is the correct geometry
    "b<enter><wait5>", // Use default partition sizes
    "x<enter><wait5>", // Partition sizes ok
    "b<enter><wait10>", // Yes

    "a<enter><wait>", // Bootblocks selection: Use BIOS console

    "d<enter><wait>", // Custom installation
    // Distribution set:
    "f<enter><wait5>", // Compiler tools
    "x<enter><wait5>", // Install selected sets

    "a<enter><wait4m>", // Install from: install image media

    "<enter><wait5>", // Hit enter to continue

    // Configure the additional items as needed

    // Change root password
    "d<enter><wait5>",
    "a<enter><wait5>", // Yes
    "${var.root_password}<enter><wait5>", // New password
    "${var.root_password}<enter><wait5>", // New password
    "${var.root_password}<enter><wait5>", // Retype new password

    // Add a user
    "o<enter><wait5>",
    "${var.secondary_user_username}<enter><wait5>", // username
    "a<enter><wait5>", // Add user to group wheel, Yes
    "a<enter><wait5>", // User shell, sh
    "${var.secondary_user_password}<enter><wait5>", // New password
    "${var.secondary_user_password}<enter><wait5>", // New password
    "${var.secondary_user_password}<enter><wait5>", // New password

    "g<enter><wait5>", // Enable sshd
    "h<enter><wait5>", // Enable ntpd
    "i<enter><wait5>", // Run ntpdate at boot

    // Configure network
    "a<enter><wait5>",
    "a<enter><wait5>", // first interface
    "<enter><wait5>", // Network media type
    "a<enter><wait20>", // Perform autoconfiguration, Yes
    "<enter><wait5>", // Your DNS domain
    "a<enter><wait5>", // Are they OK, Yes
    "a<enter><wait5>", // Is the network information correct, Yes

    // Enable installation of binary packages
    "e<enter><wait5>",
    "x<enter><wait2m>",
    "<enter><wait5>", // Hit enter to continue

    "x<enter><wait5>", // Finished configuring
    "<enter><wait5>", // Hit enter to continue

    // post install configuration
    "e<enter><wait5>", // Utility menu
    "a<enter><wait5>", // Run /bin/sh

    // shell
    "ftp -o /tmp/post_install.sh http://{{.HTTPIP}}:{{.HTTPPort}}/resources/post_install.sh<enter><wait10>",
    "sh /tmp/post_install.sh && exit<enter><wait5>",

    "x<enter><wait5>", // Exit Utility menu
    "d<enter>", // Reboot the computer
  ]

  ssh_username = "root"
  ssh_password = var.root_password
  ssh_timeout = "10000s"

  qemuargs = [
    ["-cpu", var.cpu_type],
    ["-boot", "strict=off"],
    ["-monitor", "none"],
    ["-device", "virtio-scsi-pci"],
    ["-device", "scsi-hd,drive=drive0,bootindex=0"],
    ["-device", "scsi-cd,drive=drive1,bootindex=1"],
    ["-drive", "if=none,file={{ .OutputDir }}/{{ .Name }},id=drive0,cache=writeback,discard=ignore,format=qcow2"],
    ["-drive", "if=none,file=${local.iso_full_target_path},id=drive1,media=disk,format=raw,readonly=on"],
    ["-serial", "stdio"],
    ["-netdev", "user,id=user.0,hostfwd=tcp::{{ .SSHHostPort }}-:22,ipv6=off"]
  ]

  iso_checksum = var.checksum
  iso_target_extension = local.iso_target_extension
  iso_target_path = local.iso_target_path
  iso_urls = [
    "https://cdn.netbsd.org/pub/NetBSD/images/${var.os_version}/${local.image}"
  ]

  http_directory = "."
  output_directory = "output"
  shutdown_command = "/sbin/poweroff"
  vm_name = local.vm_name
}

build {
  sources = ["qemu.qemu"]

  provisioner "shell" {
    script = "resources/provision.sh"
    environment_vars = [
      "SECONDARY_USER=${var.secondary_user_username}"
    ]
  }
}
