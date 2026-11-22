{
  # Add my private PKI's CA certificate to the system-wide trust store.
  security.pki.certificateFiles = [
    ../../certs/ecc-ca.crt
  ];

  # eMudhra intermediate CA compromise (disclosed 2026-10-20): distrust the two
  # roots that the compromised intermediates chain to or are cross-signed by.
  # https://emudhra.we-have-a-problem.com/
  #
  # "emSign ECC Root CA - G3" was blocklisted here until NSS removed the cert
  # from certdata in response to the same disclosure - and buildcatrust
  # hard-fails the cacert build when a blocklisted cert is absent from the
  # store. The entry had to go; the protection stands regardless, since the
  # cert is no longer shipped in the bundle at all.
  security.pki.caCertificateBlacklist = [
    "Comodo AAA Services root"
  ];
}
