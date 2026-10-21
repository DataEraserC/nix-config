{
  # Add my private PKI's CA certificate to the system-wide trust store.
  security.pki.certificateFiles = [
    ../../certs/ecc-ca.crt
  ];

  # eMudhra intermediate CA compromise (disclosed 2026-10-20): distrust the two
  # roots that the compromised intermediates chain to or are cross-signed by.
  # https://emudhra.we-have-a-problem.com/
  security.pki.caCertificateBlacklist = [
    "emSign ECC Root CA - G3"
    "Comodo AAA Services root"
  ];
}
