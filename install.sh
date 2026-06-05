#!/bin/bash

# Ask for CPU vendor
clear
loop=1
while [[ $loop == 1 ]]; do
    clear
    echo -e '\e[3m'"Currently, only Intel and AMD CPUs are supported."'\e(B\e[m'
    echo -e '\e[3m'"Select your CPU manufacturer:"'\e(B\e[m'
    echo
    echo -e '\e[36m'"[1]" '\e(B\e[m'"Intel"
    echo -e '\e[36m'"[2]" '\e(B\e[m'"AMD"
    echo -e '\e[36m'"[Q]" '\e(B\e[m'"Exit"
    read -n 1 choice
    case $choice in
        1)
            cpuman="intel"
            loop=0
            ;;
        2)
            cpuman="amd"
            loop=0
            ;;
        q|Q)
            clear
            exit 1
            ;;
        *)
            ;;
    esac
done
clear

# Check that virtualisation is supported and enabled
case $(grep -cE 'vmx|svm' /proc/cpuinfo) in
    0)
        echo -e '\e[1m\e[31m'"[FAIL]" '\e(B\e[m'"Virtualisation is unsupported or disabled!"
        echo -e '\e[1m\e[34m'"[INFO]" '\e(B\e[m'"Check virtualisation options in BIOS/UEFI settings!"
        echo -e '\e[1m\e[37m'"[STOP]" '\e(B\e[m'"No CPU virtualisation support found."
        exit 2
        ;;
    *)
        echo -e '\e[1m\e[32m'"[ OK ]" '\e(B\e[m'"Virtualisation is supported and enabled."
        ;;
esac

# Check that KVM is supported
if [[ -e /dev/kvm ]]; then
    echo -e '\e[1m\e[32m'"[ OK ]" '\e(B\e[m'"KVM is supported."
else
    echo -e '\e[1m\e[31m'"[FAIL]" '\e(B\e[m'"KVM is not supported!"
    echo -e '\e[1m\e[37m'"[STOP]" '\e(B\e[m'"No KVM support found."
    exit 3
fi

# Create new log in kvm-install.log
if [[ -s kvm-install.log ]]; then
    echo "" >> kvm-install.log
    echo "LOG START: $(date)" >> kvm-install.log
else
    echo "LOG START: $(date)" > kvm-install.log
fi

# Check that KVM kernel modules are loaded
if lsmod | grep -Eq '^kvm\s' && (lsmod | grep -Eq '^kvm_intel\s' || lsmod | grep -Eq '^kvm_amd\s'); then
    echo -e '\e[1m\e[32m'"[ OK ]" '\e(B\e[m'"KVM kernel modules are loaded."
else
    # Attempt to load KVM kernel modules
    echo -e '\e[1m\e[33m'"[WARN]" '\e(B\e[m'"KVM kernel modules are not loaded, attempting to load now..."
    if [[ $cpuman == "intel" ]]; then
        sudo modprobe kvm_intel 2>&1 | tee -a kvm-install.log &>/dev/null
    else
        sudo modprobe kvm_amd 2>&1 | tee -a kvm-install.log &>/dev/null
    fi
    case ${PIPESTATUS[0]} in
        0)
            echo -e '\e[1m\e[32m'"[ OK ]" '\e(B\e[m'"Kernel modules loaded successfully."
            ;;
        *)
            echo -e '\e[1m\e[31m'"[FAIL]" '\e(B\e[m'"Failed to load kernel modules!"
            echo -e '\e[1m\e[37m'"[STOP]" '\e(B\e[m'"Could not enable KVM. Check kvm-install.log for details."
            exit 3
            ;;
    esac
fi

# Install needed packages
echo -e '\e[1m\e[34m'"[INFO]" '\e(B\e[m'"Installing required packages..."
sudo pacman -Syy 2>&1 | tee -a kvm-install.log &>/dev/null
case ${PIPESTATUS[0]} in
    0)
        echo -e '\e[1m\e[32m'"[ OK ]" '\e(B\e[m'"Synchronised package databases."
        ;;
    *)
        echo -e '\e[1m\e[31m'"[FAIL]" '\e(B\e[m'"Failed to synchronise package databases!"
        echo -e '\e[1m\e[37m'"[STOP]" '\e(B\e[m'"Check your internet connection. See kvm-install.log for details."
        exit 4
        ;;
esac
sudo pacman -S --needed --noconfirm qemu-full virt-manager virt-viewer libvirt dnsmasq edk2-ovmf swtpm iptables-nft 2>&1 | tee -a kvm-install.log | grep --line-buffered -E '::'
case ${PIPESTATUS[0]} in
    0)
        echo -e '\e[1m\e[32m'"[ OK ]" '\e(B\e[m'"Installed required packages."
        ;;
    *)
        echo -e '\e[1m\e[31m'"[FAIL]" '\e(B\e[m'"Failed to install required packages!"
        echo -e '\e[1m\e[37m'"[STOP]" '\e(B\e[m'"Installation failed. Check kvm-install.log for details."
        exit 5
        ;;
esac

# Enable systemd service
sudo systemctl enable libvirtd 2>&1 | tee -a kvm-install.log &>/dev/null
case ${PIPESTATUS[0]} in
    0)
        echo -e '\e[1m\e[32m'"[ OK ]" '\e(B\e[m'"Enabled system service."
        ;;
    *)
        echo -e '\e[1m\e[31m'"[FAIL]" '\e(B\e[m'"Failed to enable system service!"
        echo -e '\e[1m\e[37m'"[STOP]" '\e(B\e[m'"Could not enable libvirtd. Check kvm-install.log for details."
        exit 6
        ;;
esac
sudo systemctl start libvirtd 2>&1 | tee -a kvm-install.log &>/dev/null
case ${PIPESTATUS[0]} in
    0)
        echo -e '\e[1m\e[32m'"[ OK ]" '\e(B\e[m'"Started system service."
        ;;
    *)
        echo -e '\e[1m\e[31m'"[FAIL]" '\e(B\e[m'"Failed to start system service!"
        echo -e '\e[1m\e[37m'"[STOP]" '\e(B\e[m'"Could not start libvirtd. Check kvm-install.log for details."
        exit 7
        ;;
esac

# Add user to libvirt group
sudo usermod -aG libvirt "$(whoami)" 2>&1 | tee -a kvm-install.log &>/dev/null
case ${PIPESTATUS[0]} in
    0)
        echo -e '\e[1m\e[32m'"[ OK ]" '\e(B\e[m'"Added user to libvirt group."
        ;;
    *)
        echo -e '\e[1m\e[33m'"[WARN]" '\e(B\e[m'"Failed to add user to libvirt group. The VM manager is installed, but you may be unable to run VMs."
        ;;
esac

# Enable virtual network
sudo virsh net-start default 2>&1 | tee -a kvm-install.log &>/dev/null
case ${PIPESTATUS[0]} in
    0)
        echo -e '\e[1m\e[32m'"[ OK ]" '\e(B\e[m'"Started virtual network."
        ;;
    *)
        echo -e '\e[1m\e[33m'"[WARN]" '\e(B\e[m'"Failed to start virtual network."
        ;;
esac
sudo virsh net-autostart default 2>&1 | tee -a kvm-install.log &>/dev/null
case ${PIPESTATUS[0]} in
    0)
        echo -e '\e[1m\e[32m'"[ OK ]" '\e(B\e[m'"Enabled virtual network."
        ;;
    *)
        echo -e '\e[1m\e[33m'"[WARN]" '\e(B\e[m'"Failed to enable virtual network. Your VMs may be unable to access the internet."
        ;;
esac

echo -e '\e[1m\e[34m'"[INFO]" '\e(B\e[m'"A reboot is recommended before you use QEMU/KVM!"
echo -e '\e[1m\e[35m'"[DONE]" '\e(B\e[m'"Installation complete. QEMU/KVM can be managed in Virtual Machine manager."
