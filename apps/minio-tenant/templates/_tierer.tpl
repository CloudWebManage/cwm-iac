{{- define "tierer.validate" -}}
{{- $t := .Values.tierer -}}
{{- if not (has ($t.mode | toString) (list "audit" "apply")) -}}
{{- fail "tierer.mode must be audit or apply" -}}
{{- end -}}
{{- range $key := list "apply" "high_include_current" "coverage_enabled" "probes_enabled" -}}
{{- if not (has (index $t $key | toString) (list "true" "false")) -}}
{{- fail (printf "tierer.%s must be true or false" $key) -}}
{{- end -}}
{{- end -}}
{{- if and (eq ($t.mode | toString) "apply") (ne ($t.apply | toString) "true") -}}
{{- fail "tierer.apply must be true in apply mode" -}}
{{- end -}}
{{- range $key := list "low_hours" "high_hours" "restore_days" "chunk_size" -}}
{{- if not (regexMatch "^[1-9][0-9]*$" (index $t $key | toString)) -}}
{{- fail (printf "tierer.%s must be a positive integer" $key) -}}
{{- end -}}
{{- end -}}
{{- if gt (mul (int64 $t.chunk_size) (add (int64 $t.low_hours) (int64 $t.high_hours))) 10000 -}}
{{- fail "tierer.chunk_size * (low_hours + high_hours) must not exceed 10000" -}}
{{- end -}}
{{- if and (eq ($t.coverage_enabled | toString) "true") (or (empty $t.coverage_template) (empty $t.coverage_value)) -}}
{{- fail "enabled tierer coverage requires coverage_template and coverage_value" -}}
{{- end -}}
{{- range $key := list "daily_transition_attempts" "daily_transition_bytes" "daily_restore_attempts" "daily_restore_bytes" -}}
{{- $value := index $t $key | toString -}}
{{- if and (ne $value "") (or (not (regexMatch "^[1-9][0-9]*$" $value)) (le (int64 $value) 0)) -}}
{{- fail (printf "tierer.%s must be empty or a positive int64" $key) -}}
{{- end -}}
{{- end -}}
{{- range $key := list "exclude_buckets" "exclude_bucket_prefixes" -}}
{{- $value := index $t $key | toString -}}
{{- if ne $value "" -}}
{{- $items := splitList "," $value -}}
{{- if ne (len $items) (len (uniq $items)) -}}{{- fail (printf "tierer.%s contains duplicates" $key) -}}{{- end -}}
{{- range $item := $items -}}
{{- if or (empty $item) (ne $item (trim $item)) -}}{{- fail (printf "tierer.%s contains blanks or surrounding whitespace" $key) -}}{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
