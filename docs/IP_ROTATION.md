# Strategies for efficient server IP rotation

This guide outlines practical ways to rotate the public IP that Outline/Shadowsocks clients connect to, with the goals of:

- Minimizing downtime during a rotation
- Avoiding full server rebuilds and repeated package installs
- Keeping operations simple and automatable on AWS
- Staying mindful of cost, quotas, and provider policies

Important notes
- Always review and comply with local laws and your cloud provider’s Terms of Service.
- Pricing, limits, and features can change; verify with AWS documentation before adopting a strategy at scale.


1) Keep one server, rotate its public IP via a pool (recommended for fast swaps)

Two common variants depending on the AWS product you use:

A. EC2 + Elastic IP pool
- What: Run a single small EC2 instance with Outline installed. Pre‑allocate several Elastic IPs (EIPs) in the region. When you need a new address, associate a different EIP with the instance.
- Why: Associations are fast (usually seconds) and you don’t have to reinstall anything.
- How (high level):
  - Allocate several EIPs up front.
  - Associate one EIP to your EC2 instance.
  - On block: disassociate the current EIP, then associate a different one from the pool.
- Pros: Very quick cutover; underlying instance stays warm; simple to automate with AWS CLI or SDK.
- Cons: Unattached EIPs may incur hourly cost; regional account quotas limit how many you can hold; the new EIP could also be blocked over time.

B. Lightsail + Static IP pool (closest to this repo)
- What: Keep a single Lightsail instance running Outline. Allocate multiple Lightsail Static IPs in the same region. Attach one Static IP at a time to the instance and swap when needed.
- Why: Similar speed to EC2 EIP swaps while letting you continue to use Lightsail.
- How (high level CLI):
  - aws lightsail allocate-static-ip --static-ip-name ip-a
  - aws lightsail attach-static-ip --static-ip-name ip-a --instance-name <instance>
  - On block: attach a different allocated static IP name (ip-b) to the same instance; the prior one becomes free to re‑use later.
- Pros: Fast swaps; reuse your existing Lightsail workflow and pricing model.
- Cons: Static IP quotas apply; you can attach only one Static IP at a time; small propagation window during IP change.

Operational tips for IP‑pool approaches
- Maintain a small pool (e.g., 3–10) so you can rotate without waiting for provider cooldowns or reputation to recover.
- Automate attachment/detachment and simple health checks. Consider a cooldown before reusing a recently blocked IP.
- If your clients use a DNS hostname, expect a short disconnect during the swap as clients reconnect.


2) Replaceable servers with a baked image (fast rebuilds when you must rotate hosts)

- What: Instead of reinstalling Outline from scratch each time, pre‑bake an image:
  - EC2: Create an AMI after you’ve installed and configured Outline once.
  - Lightsail: Use the existing user‑data/remote‑script flow in this repo, or create a snapshot to speed up rebuilds.
- Process: When blocked, launch a new instance from the image (or with our automation), open ports, fetch the key, update your S3 object (or DNS), then optionally terminate the old instance.
- Pros: Fresh IP per rebuild; consistent configuration; easy to parallelize across regions/providers.
- Cons: Still incurs several minutes of downtime for boot and warm‑up; you’ll issue new access keys/ports when the server changes.

Where this repo helps
- main.sh and scripts/create-lightsail-instance.sh already automate bring‑up, port open, key retrieval, and upload to S3.
- To reduce setup time further, consider using a snapshot or expanding remote‑script.sh to pre‑pull packages and tune sysctls/ufw.


3) DNS fronting over a hostname (decouples client config from raw IP)

- What: Distribute a hostname (e.g., ss.example.com) in your Shadowsocks URL instead of a bare IP. Map that hostname to your current server IP.
- Why: Rotating the IP becomes a DNS change instead of redistributing new links to users.
- How:
  - Use a low TTL (e.g., 60s) A/AAAA record in Route 53 (or another DNS provider).
  - Optional: Use health checks and failover routing to pre‑provision a standby host.
- Pros: You change DNS rather than client configs; can fail over between providers/regions.
- Cons: Some clients cache DNS longer than TTL; there will still be a brief reconnect; DNS itself can be interfered with depending on the network.

Tip
- Shadowsocks URLs support hostnames. You can keep ports/keys stable while changing only the A/AAAA record.


4) Network Load Balancer indirection (advanced)

- What: Put an AWS Network Load Balancer (NLB) in front of your instance on the TCP/UDP ports Outline uses, and point your hostname to the NLB. When blocked, switch to a different NLB or target group with a different public IP set.
- Why: Lets you pre‑provision multiple public IPs on managed endpoints and swap targets behind them.
- Pros: Managed, performant, supports TCP and UDP.
- Cons: More moving parts and cost than a direct IP or Static IP; still exposes relatively stable IPs that can be blocked; setup is more complex than a simple instance.


5) Multi‑region and multi‑provider pools (resilience by diversity)

- What: Maintain a small pool of instances across multiple regions and/or clouds (AWS, GCP, DigitalOcean, etc.). Rotate your DNS or published S3 link to whichever node is currently healthy.
- Pros: Spreads risk across networks and geographies; reduces correlation of reports to a single provider/ASN.
- Cons: More accounts and automation to manage; cost multiplies with pool size.


Putting it together: a pragmatic playbook
- Short‑term (minimal change): Keep using this repo’s Lightsail automation, but allocate several Lightsail Static IPs and swap attachments instead of recreating the server every time. Publish a hostname in your Shadowsocks link, not the raw IP, and update the DNS A record on each swap.
- Medium‑term: If you outgrow Lightsail limits, migrate to a tiny EC2 instance with an Elastic IP pool and simple associate/disassociate scripting. Keep your S3 updater so downstream apps can read the current endpoint reliably.
- Long‑term: Add a small, diverse pool across regions/providers and automate DNS failover with Route 53 health checks or an external monitor that updates your S3/DNS on failures or blocks.


Example AWS CLI snippets (for planning/reference)
- Lightsail Static IP swap:
  - Allocate once: aws lightsail allocate-static-ip --static-ip-name ip-a
  - Attach to instance: aws lightsail attach-static-ip --static-ip-name ip-a --instance-name Outline-Server
  - Switch to a different one later: aws lightsail attach-static-ip --static-ip-name ip-b --instance-name Outline-Server
- EC2 Elastic IP swap:
  - Allocate once: aws ec2 allocate-address --domain vpc
  - Associate: aws ec2 associate-address --allocation-id eipalloc-xxxx --instance-id i-xxxx
  - Change: aws ec2 disassociate-address --association-id eipassoc-xxxx; then associate a different allocation-id

Caveats and hygiene
- Keep security groups/firewalls tight: only the required TCP/UDP ports.
- Avoid reusing an IP too quickly; keep a queue (e.g., do not reuse within N days).
- Track costs: unattached EIPs/Static IPs and load balancers can accrue charges.
- Log rotations and maintain a simple runbook so you can quickly revert if a swap misbehaves.


FAQ
- Will a Static IP/EIP prevent blocks? No. These techniques only make rotating faster when a block happens.
- Can I make rotation completely seamless? There is usually a brief reconnect as clients pick up the change. Hostname‑based configs plus quick swap automation minimize the impact.
- Do I need new access keys after each rotation? If you keep the same server and only change its public IP, the existing keys continue to work.

