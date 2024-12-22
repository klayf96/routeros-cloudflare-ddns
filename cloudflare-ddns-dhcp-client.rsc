# Cloudflare DDNS script IPv4 r1.34 for RouterOS v7 (DHCP Client)
# by klayf <contact@klayf.com>

:if ($bound=1) do={

  ######## Please edit below ########

  :local cfDomainName   "your.domain.com"
  :local cfDNSZoneId    "your_API_Zone_ID"
  :local cfAPIToken     "your_API_Token"
  :local verifyAddr     false

  ###################################

  :local wanAddr $"lease-address"
  :delay 1s;

  :if ($verifyAddr = true) do={
    :local prvCIDR 10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,100.64.0.0/10;
    :foreach doVerifyAddr in=$prvCIDR do={
      if ($wanAddr in $doVerifyAddr) do={
        :log warning "[Cloudflare DDNS] private address has been leased"
        :onerror getPubAddr in={
        :local pubAddr ([/tool fetch mode=http url="http://checkip.amazonaws.com" output=user as-value]->"data")
        :set wanAddr ([:pick $pubAddr 0 ([:len $pubAddr] - 1)])
        } do={:log error "[Cloudflare DDNS] public ip address cannot be resolved"; :error "err013"}
      }
    }
  }

  :local cfGetURL    "https://api.cloudflare.com/client/v4/zones/$cfDNSZoneId/dns_records?type=A&name=$cfDomainName"
  :local cfGetHeader "Authorization: Bearer $cfAPIToken, Content-Type: application/json"
  :local cfDNSGet    ""

  :onerror cfGetInfo in={
    :set cfDNSGet    ([/tool fetch mode=https http-method=get output=user http-header-field=$cfGetHeader url=$cfGetURL as-value]->"data")
  } do={:log error "[Cloudflare DDNS] domain credentials are incorrect or the server cannot be accessed"; :error "err015"}

  :if ([:len $cfDNSGet] != 0) do={
    :local cfDNSRecordId ([:deserialize from=json value=([:pick $cfDNSGet 11 ([:len $cfDNSGet]-1)])]->"id")
    :local cfDNSTtl      ([:deserialize from=json value=([:pick $cfDNSGet 11 ([:len $cfDNSGet]-1)])]->"ttl")
    :local cfDNSProxied  ([:deserialize from=json value=([:pick $cfDNSGet 11 ([:len $cfDNSGet]-1)])]->"proxied")
    :local cfPrevAddr    ([:deserialize from=json value=([:pick $cfDNSGet 11 ([:len $cfDNSGet]-1)])]->"content")

    :if ($cfPrevAddr = $wanAddr) do={
      :log info "[Cloudflare DDNS] current address is already registered and will not be updated";
    } else={
      :onerror cfUpdate in={
        :local cfUpdateURL    "https://api.cloudflare.com/client/v4/zones/$cfDNSZoneId/dns_records/$cfDNSRecordId"
        :local cfUpdateHeader "Authorization: Bearer $cfAPIToken, Content-Type: application/json"
        :local cfUpdateData   "{\"type\":\"A\",\"name\":\"$cfDomainName\",\"content\":\"$wanAddr\",\"ttl\":$cfDNSTtl,\"proxied\":$cfDNSProxied}"
        :local cfDNSUpdate    [/tool fetch mode=https http-method=put output=user http-header-field=$cfUpdateHeader http-data=$cfUpdateData url=$cfUpdateURL as-value]
        :log info "[Cloudflare DDNS] dns record updated! [ $cfPrevAddr -> $wanAddr ]"
      } do={:log error "[Cloudflare DDNS] an error occurred while updating the dns record"; :error "err014"}
    }
  }
  
} else={:log warning "[Cloudflare DDNS] DHCP Client detected a change, waiting for an address lease"}
