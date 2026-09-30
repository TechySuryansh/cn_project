# Video Presentation Script: 5-Minute Phase 1 Demonstration
**Team Name:** AEIN (*Another Error In Network*)  
**Recommended Video Filename:** `CN_Phase1_[Section]_AEIN_LAN.mp4` (e.g., `CN_Phase1_S1_AEIN_LAN.mp4`)  
**Maximum Duration:** 5:00 minutes (Target: 4:40 to stay comfortably within limits)  
**Maximum File Size:** 500 MB (1080p MP4 recommended)  
**Submission Requirement:** Google Drive Link set to *"Anyone with the link can view"* (test in Incognito).

---

## ⏱️ Master Timeline Overview

| Timecode | Segment | Purpose / Focus |
|---|---|---|
| **0:00 – 0:45** | **Part 1: Team & Architecture Intro** | Team AEIN intro, roles, IPs, LAN topology |
| **0:45 – 1:45** | **Part 1: Setup Flow & Master Status** | Network addressing (`macos-network-info.sh`), `./bin/status` all green |
| **1:45 – 3:15** | **Part 2: Configuration Deep-Dive** | Scoped DNS, TLS 1.3 / HTTP/2, Load Balancing, HTTP Caching |
| **3:15 – 4:45** | **Part 3: Section 5 Failure Demos (D3)** | All 5 Failure Scenarios (DNS server, DNS record, 1 backend down, both down, wrong port) |
| **4:45 – 5:00** | **Conclusion & Outro** | Final summary & sign-off |

---

## 🛠️ Pre-Recording Checklist (Do this 1 minute BEFORE recording)
1. **Cache Sudo Credentials:**
   Run this in your terminal so no password prompt interrupts your recording:
   ```bash
   sudo -v
   ```
2. **Terminal Window Setup:**
   - Font size: `16pt` or `18pt` (easy to read in 1080p video).
   - Clear the terminal screen:
   ```bash
   clear
   ```
3. **Verify Everything is Active:**
   ```bash
   ./bin/status
   ```
   Ensure all checks return `OK` or `PASS`.

---

# 🎬 Complete Spoken Script & Terminal Commands

---

### PART 1: TEAM INTRO & SETUP FLOW (0:00 – 1:45)

#### [0:00 – 0:45] Team & Architecture Introduction
**🎙️ What to Say:**
> *"Hello everyone and welcome to our Computer Networks Phase 1 demonstration. We are Team **AEIN**, which stands for **Another Error In Network**.  
> Our distributed architecture is deployed across physical Mac machines over a local area network:
> - **Mitul (Mac 1)** is running the local DNS server via dnsmasq on port 53, the test controller, and Backend B on port 3002.
> - **Hardik (Mac 2)** is hosting the TLS Edge Reverse Proxy using Nginx on port 8443, as well as Backend A on port 3001.
> - Our teammates **Akshat** and **Vaibhav** are collaborating on backend development and edge routing configurations."*

---

#### [0:45 – 1:15] Network Addressing (Task A)
**⌨️ Run Command:**
```bash
./scripts/macos-network-info.sh
```
**🎙️ What to Say:**
> *"First, here is our physical network addressing for Task A. We are on the Wi-Fi interface en0 with IP address `10.80.3.253` on a `/24` subnet with gateway `10.80.3.250`. Hardik's Mac on the same subnet is at `10.80.3.171`."*

---

#### [1:15 – 1:45] System Master Status & Setup Flow
**⌨️ Run Command:**
```bash
./bin/status
```
**🎙️ What to Say:**
> *"Next, we run `./bin/status` to show the active state of our entire cluster. As you can see:
> - dnsmasq is active and answering queries.
> - Client resolver correctly maps the test domain to the Edge IP.
> - The Edge proxy on Mac 2 is listening on port 8443 with valid TLS.
> - Both Backend A on Hardik's machine and Backend B on my machine are healthy, and the application reports round-robin load balancing."*

---

### PART 2: HOW CONFIGURATION IS WORKING (1:45 – 3:15)

#### [1:45 – 2:10] 1. Scoped DNS Resolution
**⌨️ Run Commands:**
```bash
cat /etc/resolver/team1.test
```
```bash
dscacheutil -q host -a name app.team1.test
```
```bash
dig @127.0.0.1 +noall +answer app.team1.test
```
**🎙️ What to Say:**
> *"Now let's examine the configuration.  
> First, DNS resolution: Instead of hijacking the entire system's DNS settings, we use macOS's scoped resolver in `/etc/resolver/team1.test`. Only queries for the `.team1.test` domain are forwarded to our local DNS server at `127.0.0.1`.  
> Verifying through `dscacheutil` and `dig`, `app.team1.test` resolves accurately to Hardik's Edge IP `10.80.3.171`."*

---

#### [2:10 – 2:35] 2. TLS 1.3 & HTTP/2 Validation
**⌨️ Run Command:**
```bash
curl -v https://app.team1.test:8443/__edge/health 2>&1 | grep -E "(ALPN|SSL connection|HTTP/2)"
```
**🎙️ What to Say:**
> *"Second, TLS and Transport security: When connecting to our edge gateway over port 8443, curl completes the handshake using TLS 1.3 with zero `-k` or insecure flags because our private Root CA is installed and trusted in the macOS System Keychain. ALPN successfully negotiates HTTP/2."*

---

#### [2:35 – 2:55] 3. Load Balancing Across Backends
**⌨️ Run Command:**
```bash
./tests/test_load_balancing.sh
```
**🎙️ What to Say:**
> *"Third, Load Balancing: Running our automated test suite demonstrates round-robin balancing between Backend A on Hardik's Mac and Backend B on my Mac. Responses alternate cleanly: B A B A B A, with each backend taking an equal share of the load."*

---

#### [2:55 – 3:15] 4. HTTP Caching & Conditional Requests
**⌨️ Run Command:**
```bash
./tests/test_cache.sh
```
**🎙️ What to Say:**
> *"Fourth, HTTP Caching: Testing our static endpoint confirms RFC 9111 compliance. Nginx emits a `Cache-Control: max-age=60` header along with an ETag. When the client sends an `If-None-Match` request, the edge proxy responds with `304 Not Modified`, saving network bandwidth."*

---

### PART 3: SECTION 5 FAILURE DEMONSTRATIONS (3:15 – 4:45)

> *Here we reproduce the 5 exact failure scenarios from the Section 5 evaluation table, explaining root cause, network layer, and demonstrating recovery.*

---

#### [3:15 – 3:35] Scenario 1: Wrong DNS Server Configured on Client
**⌨️ Run Commands:**
```bash
dig @192.0.2.53 +time=1 +tries=1 app.team1.test
```
```bash
ping -c 2 10.80.3.171
```
**🎙️ What to Say:**
> *"Scenario 1: Wrong DNS server configured on the client.  
> If the client queries an invalid DNS IP like `192.0.2.53`, the query times out with no server reached. However, running a direct ping to the Edge IP `10.80.3.171` succeeds with 0% packet loss.  
> **Explanation:** This demonstrates the separation between the Application Layer (DNS name resolution) and Network Layer (L3 IP routing). Network connectivity is intact, but name resolution failed."*

---

#### [3:35 – 3:55] Scenario 2: DNS Record Points to Wrong IP Address
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
**🎙️ What to Say:**
> *"Scenario 2: DNS record points to a wrong IP.  
> We inject an unroutable IP `192.0.2.99` into dnsmasq. When we query `dig`, DNS happily answers with `192.0.2.99`. But when we run curl, the connection times out.  
> **Explanation:** DNS is purely a directory service, not a connectivity validator. It returns the registered record, but the TCP SYN packet fails at the Transport Layer because the destination IP is unroutable. We now rollback the record."*

---

#### [3:55 – 4:15] Scenario 3: One Backend is Stopped (Failover)
**⌨️ Run Commands:**
```bash
./macs/mac4-akshat/stop.sh
```
```bash
curl -sS https://app.team1.test:8443/api/status && echo
```
```bash
curl -sS https://app.team1.test:8443/api/status && echo
```
```bash
./macs/mac4-akshat/start.sh
```
**🎙️ What to Say:**
> *"Scenario 3: One backend is stopped.  
> We simulate a crash by stopping Backend B. Now when we send requests to the edge, every request succeeds with 200 OK and is routed to Backend A on Hardik's machine.  
> **Explanation:** Nginx's passive health checks and `proxy_next_upstream` directive detect the dead upstream and immediately fail over to the surviving backend with zero dropped user requests. We now restart Backend B."*

---

#### [4:15 – 4:30] Scenario 4: Both Backends are Stopped
**⌨️ Run Commands:**
```bash
./macs/mac4-akshat/stop.sh
```
```bash
curl -i https://app.team1.test:8443/api/status
```
```bash
./macs/mac4-akshat/start.sh
```
**🎙️ What to Say:**
> *"Scenario 4: Upstream backend failure (Both backends stopped).  
> If upstreams are unavailable, when the client requests the API, the edge proxy responds with `HTTP/2 502 Bad Gateway`.  
> **Explanation:** DNS resolution, TCP connection, and TLS 1.3 handshake all succeed at the Edge Gateway, but because there are no available upstream servers, the proxy itself generates the 502 error. We restore Backend B."*

---

#### [4:30 – 4:45] Scenario 5: Wrong Destination Port on Client
**⌨️ Run Command:**
```bash
curl -v --max-time 2 https://app.team1.test:9999/api/status 2>&1 | grep -E "(Trying|Failed|Connection refused)"
```
**🎙️ What to Say:**
> *"Scenario 5: Wrong destination port on the client.  
> When the client attempts to connect to port 9999 instead of 8443, the domain resolves correctly to `10.80.3.171`, but the OS immediately returns `Connection refused`.  
> **Explanation:** This highlights the distinction between Network Layer host addressing (IP) and Transport Layer process addressing (Port). The destination host is alive, but no listening socket exists on port 9999, so the OS sends a TCP RST packet."*

---

### CONCLUSION & OUTRO (4:45 – 5:00)

**🎙️ What to Say:**
> *"To summarize: We have demonstrated DNS resolution, TLS 1.3 security, reverse proxy load balancing, HTTP caching, and analyzed network behavior across 5 distinct failure modes.  
> This concludes the Phase 1 presentation for Team **AEIN (Another Error In Network)**. Thank you!"*

---

## 📋 Quick Copy-Paste Cheatsheet for Video Recording

Keep these exact commands ready on your terminal:

```bash
# === PRE-RECORDING ===
sudo -v
clear

# === PART 1: INTRO & SETUP (0:00 - 1:45) ===
./scripts/macos-network-info.sh
./bin/status

# === PART 2: CONFIGURATION (1:45 - 3:15) ===
cat /etc/resolver/team1.test
dscacheutil -q host -a name app.team1.test
dig @127.0.0.1 +noall +answer app.team1.test
curl -v https://app.team1.test:8443/__edge/health 2>&1 | grep -E "(ALPN|SSL connection|HTTP/2)"
./tests/test_load_balancing.sh
./tests/test_cache.sh

# === PART 3: FAILURE DEMONSTRATIONS (3:15 - 4:45) ===
# 1. Wrong DNS Server
dig @192.0.2.53 +time=1 +tries=1 app.team1.test
ping -c 2 10.80.3.171

# 2. Wrong DNS Record
./bin/failure-demo wrong-dns-record break
dig @127.0.0.1 +short app.team1.test
curl --connect-timeout 2 https://app.team1.test:8443/api/status
./bin/failure-demo wrong-dns-record rollback

# 3. One Backend Stopped
./macs/mac4-akshat/stop.sh
curl -sS https://app.team1.test:8443/api/status && echo
curl -sS https://app.team1.test:8443/api/status && echo
./macs/mac4-akshat/start.sh

# 4. Both Backends / 502 Bad Gateway
./macs/mac4-akshat/stop.sh
curl -i https://app.team1.test:8443/api/status
./macs/mac4-akshat/start.sh

# 5. Wrong Port
curl -v --max-time 2 https://app.team1.test:9999/api/status 2>&1 | grep -E "(Trying|Failed|Connection refused)"
```
