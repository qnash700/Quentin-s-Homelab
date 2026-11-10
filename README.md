# Active Directory Home Lab

## Objective
Built a Windows Active Directory environment in VirtualBox to practice the core tasks of a help desk and systems administrator: setting up a domain controller, configuring DNS and DHCP, managing users, joining a client to the domain, troubleshooting network issues, and automating user creation with PowerShell.

## Lab Setup

| Machine | OS | Role | IP Address |
|---|---|---|---|
| Domain Controller | Windows Server 2022 | AD DS, DNS, DHCP | 192.168.10.1 (static) |
| Tuneski | Windows 11 | Domain-joined client | Assigned by DHCP |

**Domain:** `quentinlab.local`
**Hypervisor:** Oracle VirtualBox

**Network design:** The domain controller has two network adapters:
- **Ethernet** (NAT): internet access, 10.0.2.15
- **Ethernet 2** (Internal Network): lab traffic, 192.168.10.1, DNS pointed to itself (127.0.0.1)

The client connects to the same internal network and gets its address from the DC's DHCP scope.

## Tools Used
- Oracle VirtualBox
- Windows Server 2022
- Windows 11
- Active Directory Domain Services (AD DS)
- DNS and DHCP
- PowerShell

---

## 1. Static IP on the Domain Controller
Gave the DC a static IP and pointed its DNS to itself (127.0.0.1), since the DC is the DNS server for the domain.

![Static IP configuration](screenshots/staticIP.png)

## 2. DHCP Scope
Created a DHCP scope handing out 192.168.10.100 to 192.168.10.200 on a /24 network so clients get an IP automatically.

![DHCP scope](screenshots/dhcp.png)

## 3. Creating Users
Created a test user (John Smith, jsmith) in Active Directory Users and Computers.

![First user created](screenshots/1stuser.png)

---

## 4. Troubleshooting: Client Could Not Join the Domain

**Problem:** The client could not join `quentinlab.local`. Pinging the DC at 192.168.10.1 timed out, and DNS lookups were going to my ISP's DNS server instead of the DC.

![Ping failing and DNS going to ISP](screenshots/06-join-failed.png)

**Cause:** The static IP settings were on the wrong network adapters. The client's settings were on Ethernet 1 and the DC's were on Ethernet 2, so the two machines were not on the same internal network. The client couldn't reach the DC at all, and without the DC as its DNS server it had no way to find the domain.

**Diagnosis:** Ran `ipconfig /all` on the DC to see which adapter had which IP. Ethernet 2 (Internal Network) had 192.168.10.1, while Ethernet (NAT) was using the ISP's DNS servers.

![ipconfig on the DC](screenshots/05-ipconfig-dc.png)

**Fix:** Moved the IP settings to the correct adapter on each machine so both were on the internal network, and pointed the client's DNS to 192.168.10.1.

**Verified:**
- `ping 192.168.10.1` got replies
- `nslookup quentinlab.local` resolved through the DC
- The domain join succeeded

**What I learned:** When a VM has more than one network adapter, check which adapter is connected to which VirtualBox network before assigning IPs. If a domain join fails, check connectivity with `ping`, then DNS with `nslookup`, then `ipconfig /all`. Most domain join failures are DNS problems.

---

## 5. Joining the Client to the Domain
Changed the client's membership from Workgroup to the `quentinlab.local` domain and entered domain admin credentials.

![Joining the domain](screenshots/07-domain-join.png)

After fixing the network issue, the join succeeded:

![Welcome to the domain](screenshots/09-join-success.png)

## 6. Logging In as a Domain User
Logged into the client as jsmith. Windows required a new password at first login, which confirmed the account was coming from Active Directory and the "change password at next logon" setting was working.

![Domain user login](screenshots/10-domain-login.png)

---

## 7. Automating User Creation with PowerShell
Wrote a script that reads a CSV file and creates users in bulk instead of making them one at a time in ADUC. Transferred the files to the DC through a VirtualBox shared folder.

**What the script does:**
- Creates an OU for each department if it doesn't already exist
- Creates usernames in first-initial + last-name format (jsmith)
- Skips users that already exist so it can be run more than once safely
- Forces a password change at first logon
- Prompts for the initial password so it is never saved in the script or the repo
- Writes a log file of everything it did

Script: [`scripts/New-BulkADUsers.ps1`](scripts/New-BulkADUsers.ps1)
Sample data: [`scripts/users.csv`](scripts/users.csv)

```powershell
cd C:\Scripts
.\New-BulkADUsers.ps1 -CsvPath .\users.csv
```

![Script running](screenshots/12-script-running.png)
![Users and OUs created in ADUC](screenshots/13-users-created.png)

---

## What I Learned
- How Active Directory, DNS, and DHCP depend on each other
- How to troubleshoot a failed domain join with ping, nslookup, and ipconfig
- Why multi-adapter VMs need careful network configuration
- How to manage users both in the GUI and with PowerShell
- How to document a project on GitHub

## Next Steps
- Move the password and account lockout policy into a domain Group Policy Object
- Handle duplicate usernames in the script (jsmith vs jsmith2)
- Add security groups by department
- Set up Sysmon and Splunk to monitor the domain for suspicious activity
