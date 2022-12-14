{{- /* /tmp/cert.tpl */ -}}
{{ with secret "pki/issue/example-dot-com" "common_name=foo.example.com" }}
{{ .Data.certificate }}{{ end }}

{{- /* /tmp/ca.tpl */ -}}
{{ with secret "pki/issue/example-dot-com" "common_name=foo.example.com" }}
{{ .Data.issuing_ca }}{{ end }}

{{- /* /tmp/key.tpl */ -}}
{{ with secret "pki/issue/example-dot-com" "common_name=foo.example.com" }}
{{ .Data.private_key }}{{ end }}