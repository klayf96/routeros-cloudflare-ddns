:if ($bound=1) do={
  :do {
    # Cloudflare DDNS script IPv4 r1.35 for RouterOS v7 (DHCP Client)
    # (c) 2023, 2026 klayf <contact@klayf.com>

    ######## Please edit below ########

    :local cfDomainName   "your.domain.com"
    :local cfDNSZoneId    "your_API_Zone_ID"
    :local cfAPIToken     "your_API_Token"
    :local verifyAddr     false

    ###################################

    :local wanAddr $"lease-address"
    :delay 1s;

    :local cfGetURL    "https://api.cloudflare.com/client/v4/zones/$cfDNSZoneId/dns_records?type=A&name=$cfDomainName"
    :local cfGetHeader "Authorization: Bearer $cfAPIToken, Content-Type: application/json"
    :local cfDNSGet    ""

    :if ($verifyAddr) do={
      :local prvCIDR 10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,100.64.0.0/10;
      :foreach doVerifyAddr in=$prvCIDR do={
        if ($wanAddr in $doVerifyAddr) do={
          :log warning "[Cloudflare DDNS] private IP address has been leased."
          :do {
            :local pubAddr ([/tool fetch mode=http url="http://checkip.amazonaws.com" output=user as-value]->"data")
            :set wanAddr ([:pick $pubAddr 0 ([:len $pubAddr] - 1)])
          } on-error={:error "[Cloudflare DDNS] public IP address cannot be resolved."}
        }
      }
    }

    :do {
      :set cfDNSGet ([/tool fetch mode=https http-method=get output=user http-header-field=$cfGetHeader url=$cfGetURL as-value]->"data")
    } on-error={:error "[Cloudflare DDNS] domain credentials are incorrect or the server cannot be accessed."}

    :if ([:len $cfDNSGet]!=0) do={
      :local prevInfo      [:deserialize from=json value=([:pick $cfDNSGet 11 ([:len $cfDNSGet]-1)])]
      :local cfDNSRecordId ($prevInfo->"id")
      :local cfDNSTtl      ($prevInfo->"ttl")
      :local cfDNSProxied  ($prevInfo->"proxied")
      :local cfPrevAddr    ($prevInfo->"content")

      :if ($cfPrevAddr=$wanAddr) do={
        :log info "[Cloudflare DDNS] current IP address is already registered and will not be updated."
      } else={
        :do {
          :local cfUpdateURL    "https://api.cloudflare.com/client/v4/zones/$cfDNSZoneId/dns_records/$cfDNSRecordId"
          :local cfUpdateHeader "Authorization: Bearer $cfAPIToken, Content-Type: application/json"
          :local cfUpdateData   "{\"type\":\"A\",\"name\":\"$cfDomainName\",\"content\":\"$wanAddr\",\"ttl\":$cfDNSTtl,\"proxied\":$cfDNSProxied}"
          :local cfDNSUpdate    [/tool fetch mode=https http-method=put output=user http-header-field=$cfUpdateHeader http-data=$cfUpdateData url=$cfUpdateURL as-value]
          :log info "[Cloudflare DDNS] DNS record updated! [ $cfPrevAddr -> $wanAddr ]"
        } on-error={:error "[Cloudflare DDNS] an error occurred while updating the dns record."}
      }
    }
  }
} else={:log warning "dhcp-client detected a change, waiting for an address lease."}
