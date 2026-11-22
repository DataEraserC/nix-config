{
  # Add my private PKI's CA certificate to the system-wide trust store.
  security.pki.certificateFiles = [
    ../../certs/ecc-ca.crt
  ];

  # eMudhra intermediate CA compromise (disclosed 2026-10-20): distrust the two
  # roots that the compromised intermediates chain to or are cross-signed by.
  # https://emudhra.we-have-a-problem.com/
  #
  # NSS removed "emSign ECC Root CA - G3" from certdata in response, so the
  # current cacert build prints "Certs in blocklist but not in cert store" for
  # it - that warning is expected and the entry stays as defence in depth (it
  # bites again if a future NSS re-introduces or cross-signs the cert). The
  # Comodo entry still matches a live certificate.
  security.pki.caCertificateBlacklist = [
    "emSign ECC Root CA - G3"
    "Comodo AAA Services root"
  ];
}
