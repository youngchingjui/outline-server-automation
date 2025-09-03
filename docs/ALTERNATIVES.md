# Alternatives to cycling Lightsail instances/IPs

If the goal is to maintain a healthy Outline connection while avoiding IP blocks, here are some alternatives and trade-offs:

- Elastic IP rotation with EC2
  - Maintain a small EC2 instance and allocate multiple Elastic IPs (limited per account/region; you can request increases).
  - Detach/attach EIPs to shift IPs rapidly without recreating hosts.
  - Pros: Faster switching, stable underlying instance, can prewarm app.
  - Cons: EIPs incur cost when unattached; may still be blocked; service interruptions during swaps.

- NAT Gateway or NAT Instance
  - Run Outline behind a NAT and rotate the upstream egress IP by swapping NAT gateways/instances or using multiple NAT instances with different EIPs.
  - Pros: Centralized control over egress IP.
  - Cons: NAT Gateways have hourly + data processing costs; NAT instances require maintenance.

- AWS Global Accelerator or CloudFront (with TCP/UDP support constraints)
  - Front Outline with a global anycast IP and backends placed across regions.
  - Pros: Stable global IPs and performance.
  - Cons: Not applicable to all protocols/ports and may violate provider ToS; additional cost.

- AWS Network Load Balancer per-session IPs
  - NLB can expose static IPs per AZ. Rotating target groups or NLBs can change exposure.
  - Pros: Managed and scalable.
  - Cons: More complex and may not suit Outline's port needs.

- Multiple regions/pools
  - Maintain a pool of low-cost instances across regions; rotate DNS to new IPs when blocks happen.
  - Pros: Distributes reputation risk across regions/providers.
  - Cons: Requires orchestration, health checks, and DNS TTL management.

- Provider diversity
  - Mix AWS with other clouds (GCP/Linode/DigitalOcean) to reduce correlation of abuse reports to a single provider.

- Residential proxy providers / ISP IPs
  - Use third-party networks offering residential egress IPs (check legal/policy constraints).
  - Pros: Less likely to be blocked quickly.
  - Cons: Cost and compliance concerns.

- Firewall/rate-limiting and port management
  - Only expose essential ports, rotate Shadowsocks ports, and rate-limit to reduce detection.

Notes:
- Always review AWS acceptable use policies and local laws.
- Evaluate cost vs. complexity; Lightsail cycling is cheap and simple but causes downtime during each rotation.

