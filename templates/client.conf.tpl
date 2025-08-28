{{- range $server := .Hosts }}
remote {{ $server.Host }} {{ $server.Port }} {{ $server.Protocol }}
{{- end }}

verb 4
client
nobind
dev tun
cipher AES-256-GCM
key-direction 1

# Split tunneling rules
pull-filter ignore "redirect-gateway"   # Ignore server forcing all traffic through VPNs
{{- if .OvpnRoutes }}
route {{ .OvpnRoutes }}            # Route only specified networks through tunnel
{{- else }}
route 10.8.0.0 255.255.255.0            # Route only VPN subnet through tunnel
{{- end }}
tls-client
remote-cert-tls server
#redirect-gateway def1

# uncomment below lines for use with linux
#script-security 2

# if you use resolved
#up /etc/openvpn/update-resolv-conf
#down /etc/openvpn/update-resolv-conf

# if you use systemd-resolved first install openvpn-systemd-resolved package
#up /etc/openvpn/update-systemd-resolved
#down /etc/openvpn/update-systemd-resolved

{{- if .PasswdAuth }}
auth-user-pass
{{- end }}

<cert>
{{ .Cert -}}
</cert>
<key>
{{ .Key -}}
</key>
<ca>
{{ .CA -}}
</ca>
<tls-auth>
{{ .TLS -}}
</tls-auth>
