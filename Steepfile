# frozen_string_literal: true

D = Steep::Diagnostic

target :lib do
  signature "sig/generated"
  signature "sig/handwritten"
  signature "sig/external"

  check "lib"

  library "ipaddr"
  library "logger"

  configure_code_diagnostics(D::Ruby.default)
end
