# Video Presentation Script: 5-Minute Phase 1 Demonstration

**Team Name:** nexa  
**Submission Type:** Type 1 — 4 physical macOS laptops on the same LAN  
**GitHub Repo:** `https://github.com/TechySuryansh/cn_project`  
**Video File Name:** `CN_Phase1_[Section]_nexa_Type1.mp4` (e.g., `CN_Phase1_CSE1_nexa_Type1.mp4`)  
**Maximum Duration:** 5:00 minutes (Target: ~4:35 for safe margin)  
**Maximum File Size:** 500 MB (1080p MP4 recommended)  
**Submission:** Google Drive link set to *"Anyone with the link can view"* (test in Incognito).

---

## ⏱️ Video Structure (5-Minute Hard Cap)

| Time | Section | Focus |
|---|---|---|
| **0:00 – 2:00 (2 min)** | **Part 1: Team Intro & Setup Flow** | Team intro, 4-Mac roles, LAN addressing (Task A), `./bin/status` showing all green |
| **2:00 – 4:00 (2 min)** | **Part 2: How Configuration is Working** | Scoped DNS (`/etc/resolver`), TLS 1.3 / HTTP/2, Round-Robin Load Balancing, HTTP Caching / 304 |
| **4:00 – 5:00 (1 min)** | **Part 3: Section 5 Failure Demos (D3)** | L3 vs L7 separation (DNS record failure) + High-Availability Backend Failover (Nginx rerouting) |

---

## 🛠️ Pre-Recording Checklist (Run 1 minute before recording)

Run this once in your terminal before hitting Record:
```bash
sudo -v
clear
```
*(Caches your admin password so no prompt interrupts your screen recording).*

---

# 🎬 Complete Teleprompter Script & Commands

---

### PART 1: TEAM INTRO & SETUP FLOW (0:00 – 2:00)

#### [0:00 – 0:50] Team & Architecture Introduction
**🎙️ Speak:**
> *"Hello everyone, welcome to our Computer Networks Phase 1 demonstration. We are Team **nexa**.  
> Our project is deployed using **Submission Type 1: four physical macOS laptops connected directly on the same local area network**.  
> Here is how our architecture is distributed across our team:
> - **Suryansh (Mac 1)** runs the local DNS server via dnsmasq on port 53 and acts as our test client.
> - **Pranjal (Mac 2)** hosts the Edge Reverse Proxy and Load Balancer using Nginx on port 8443 with TLS termination.
> - **Ajeesh (Mac 3)** runs Backend A on port 3001.
> - **Sarvajeet (Mac 4)** runs Backend B on port 3002."*

---

#### [0:50 – 1:25] Network Addressing (Task A)
**⌨️ Run Command:**
```bash
./scripts/macos-network-info.sh
```
**🎙️ Speak:**
> *"First, here is our physical network addressing for Task A.  
> We are on Wi-Fi interface en0 with IP address `10.245.104.85` on a `/24` subnet with gateway `10.245.104.251`.  
> On the exact same LAN:
> - Pranjal's Edge is at `10.245.104.169`
> - Ajeesh's Backend A is at `10.245.104.235`
> - Sarvajeet's Backend B is at `10.245.104.126`."*

---

#### [1:25 – 2:00] Setup Flow & Cluster Master Status
**⌨️ Run Command:**
```bash
./bin/status
```
**🎙️ Speak:**
> *"To start our services, each teammate runs a single, idempotent setup script from their respective folder.  
> Running `./bin/status` on our controller provides an end-to-end audit of the entire cluster:
> - Our local dnsmasq service is active and correctly answering queries.
> - Mac 2's Edge proxy is listening on port 8443 with valid TLS.
> - Both Backend A and Backend B are answering health checks.
> - And live requests are actively load balanced."*

---

### PART 2: HOW CONFIGURATION IS WORKING (2:00 – 4:00)

#### [2:00 – 2:35] 1. Scoped DNS Resolution
**⌨️ Run Commands:**
```bash
cat /etc/resolver/team1.test
```
```bash
dig @127.0.0.1 +noall +answer app.team1.test
```
**🎙️ Speak:**
> *"Now let's examine how each layer works.  
> First, DNS resolution: Instead of altering the client's global DNS, we use macOS's scoped resolver in `/etc/resolver/team1.test`. Only queries for our domain are sent to our local DNS server at `127.0.0.1`.  
> As confirmed by `dig`, `app.team1.test` resolves cleanly to Pranjal's Edge IP `10.245.104.169`."*

---

#### [2:35 – 3:05] 2. TLS 1.3 & HTTP/2 Security
**⌨️ Run Command:**
```bash
curl -v https://app.team1.test:8443/__edge/health 2>&1 | grep -E "(ALPN|SSL connection|HTTP/2)"
```
**🎙️ Speak:**
> *"Second, Transport Layer Security:  
> When connecting over HTTPS on port 8443, curl negotiates **TLS 1.3** and **HTTP/2** with zero warnings and without any `-k` insecure flag.  
> This is because our private Root CA certificate is installed and trusted in the macOS System Keychain."*

---

#### [3:05 – 3:35] 3. Round-Robin Load Balancing
**⌨️ Run Command:**
```bash
./tests/test_load_balancing.sh
```
**🎙️ Speak:**
> *"Third, Load Balancing across our physical backends:  
> Running our test suite sends requests to the application endpoint. Nginx distributes them evenly in round-robin fashion between Backend A on Ajeesh's Mac and Backend B on Sarvajeet's Mac, alternating: B A B A B A."*

---

#### [3:35 – 4:00] 4. HTTP Caching & Conditional Requests
**⌨️ Run Command:**
```bash
./tests/test_cache.sh
```
**🎙️ Speak:**
> *"Fourth, HTTP Caching according to RFC 9111:  
> Our backends emit a `Cache-Control: max-age=60` freshness lifetime and a matching ETag. When the client sends an `If-None-Match` request, the server responds with `304 Not Modified`, verifying conditional validation and bandwidth optimization."*

---

### PART 3: SECTION 5 FAILURE DEMONSTRATIONS (4:00 – 5:00)

#### [4:00 – 4:30] Failure Demo 1: DNS Record vs IP Connectivity (L3 vs L7)
**⌨️ Run Commands:**
```bash
./bin/failure-demo wrong-dns-record break
```
```bash
dig @127.0.0.1 +short app.team1.test
```
```bash
curl --connect-timeout 2 https://app.team1.test:8443/api/status
```
```bash
./bin/failure-demo wrong-dns-record rollback
```
**🎙️ Speak:**
> *"In Section 5, we demonstrate layer separation during failure.  
> First, we point the DNS record to an unroutable IP `192.0.2.99`. `dig` returns the address, but curl immediately fails with a timeout.  
> **Key concept:** DNS is purely a directory service, not a connectivity check. Name resolution succeeded, but TCP connection failed at Layer 4. We roll back the change."*

---

#### [4:30 – 4:55] Failure Demo 2: Backend Failure & Passive Failover
**⌨️ Run Commands:**
```bash
curl -sS https://app.team1.test:8443/api/status && echo
```
```bash
./macs/mac4-sarvajeet/stop.sh
```
```bash
curl -sS https://app.team1.test:8443/api/status && echo
```
```bash
./macs/mac4-sarvajeet/start.sh
```
**🎙️ Speak:**
> *"Second, Backend Failure:  
> When both backends are up, requests balance across A and B. When we stop Backend B, the next request still returns `200 OK`, routed automatically to Backend A.  
> **Key concept:** Nginx's passive health checks detect the unresponsive port and failover instantly using `proxy_next_upstream`, ensuring high availability. We restart Backend B."*

---

#### [4:55 – 5:00] Conclusion
**🎙️ Speak:**
> *"This concludes the Phase 1 demonstration for Team **nexa**. Thank you!"*

---

## 📋 Quick Copy-Paste Cheatsheet for Recording

Keep this single file or text buffer open on half of your screen:

```bash
# === 0. PREP ===
sudo -v
clear

# === PART 1: INTRO & SETUP (0:00 - 2:00) ===
./scripts/macos-network-info.sh
./bin/status

# === PART 2: CONFIGURATION (2:00 - 4:00) ===
cat /etc/resolver/team1.test
dig @127.0.0.1 +noall +answer app.team1.test
curl -v https://app.team1.test:8443/__edge/health 2>&1 | grep -E "(ALPN|SSL connection|HTTP/2)"
./tests/test_load_balancing.sh
./tests/test_cache.sh

# === PART 3: FAILURE DEMOS (4:00 - 5:00) ===
# 1. DNS Failure
./bin/failure-demo wrong-dns-record break
dig @127.0.0.1 +short app.team1.test
curl --connect-timeout 2 https://app.team1.test:8443/api/status
./bin/failure-demo wrong-dns-record rollback

# 2. Backend Failover
curl -sS https://app.team1.test:8443/api/status && echo
./macs/mac4-sarvajeet/stop.sh
curl -sS https://app.team1.test:8443/api/status && echo
./macs/mac4-sarvajeet/start.sh
```
