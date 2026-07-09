# 🦙 Ollama VPS Free-Tier 1-Click Installer

A lightweight, production-ready, cross-platform 1-click script to install **Ollama** and run highly-efficient quantized LLMs (like **Qwen 2.5 Coder 1.5B**, **TinyLlama 1.1B**, or **Llama 3.2 1B**) on low-spec servers (e.g., **1GB RAM Free Tier VPS** on AWS EC2, GCP, Oracle Cloud).

## 🚀 Quick Install

### 🐧 Linux (Ubuntu / Debian / CentOS / RHEL)
Run the following command on your remote Linux VPS to automatically set up a 2GB swap partition, install Ollama, expose the API, and deploy your model of choice:

```bash
curl -fsSL https://raw.githubusercontent.com/Ziploot/ollama-vps-free-tier/main/install.sh | bash
```

### 🪟 Windows (Powershell - Run as Admin)
Run the following command in PowerShell (as Administrator) to set up Ollama, bind the host API, and install models:

```powershell
iwr -useb "https://raw.githubusercontent.com/Ziploot/ollama-vps-free-tier/main/install.ps1" | iex
```

## 🛠️ Features
- **Automatic Swap Allocation**: Detects low memory and configures a optimized 2GB swap space to prevent kernel Out-Of-Memory (OOM) crashes.
- **Zero Configuration API Exposure**: Auto-binds Ollama to `0.0.0.0:11434` for secure external access (no manual service files editing needed).
- **Interactive Model Selection**: Choose between Qwen 1.5B (Recommended for coding/reasoning), TinyLlama 1.1B (Ultra lightweight), or custom parameters.
- **Cross-Platform Compatibility**: Supports all popular Linux package managers and Windows Winget setup.
- **Pre-flight & Post-flight Verification**: Confirms ports and dependencies before starting installation.

## 📡 Testing the API
Once the installation completes, verify your API from your local machine:

```bash
curl -X POST http://[YOUR_VPS_IP]:11434/api/generate -d '{
  "model": "qwen2.5-coder:1.5b",
  "prompt": "Write a quicksort in JavaScript",
  "stream": false
}'
```

---
*Created and maintained by [ZipLoot](https://ziploot.blogspot.com)*
