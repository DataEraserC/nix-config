;(function () {
  "use strict"

  var LOG_TAG = "homepage"
  var STORAGE_HOST = "homepage.host"
  var STORAGE_LANG = "homepage.lang"

  var DATA = JSON.parse(document.getElementById("homepage-data").textContent)
  var LOCALES = JSON.parse(document.getElementById("homepage-i18n").textContent)

  var state = {
    lang: null,
    view: null,
    env: null,
    overlayNetwork: null,
    filter: "",
  }

  function logError(message, detail) {
    console.error("[" + LOG_TAG + "] " + message, detail)
  }

  function logWarning(message, detail) {
    console.warn("[" + LOG_TAG + "] " + message, detail)
  }

  function readStorage(key) {
    try {
      return window.localStorage.getItem(key)
    } catch (error) {
      return null
    }
  }

  function writeStorage(key, value) {
    try {
      window.localStorage.setItem(key, value)
    } catch (error) {
      // Storage can be unavailable in private or embedded contexts; the page
      // still works without persistence.
    }
  }

  function escapeHtml(value) {
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;")
  }

  function queryParam(name) {
    return new URLSearchParams(window.location.search).get(name)
  }

  function hasLocale(lang) {
    return lang && Object.prototype.hasOwnProperty.call(LOCALES, lang)
  }

  function resolveLanguage() {
    var candidates = [queryParam("lang"), readStorage(STORAGE_LANG), DATA.defaultLanguage]
    for (var i = 0; i < candidates.length; i += 1) {
      var candidate = candidates[i]
      if (hasLocale(candidate)) {
        return candidate
      }
      if (candidate) {
        logWarning("unknown locale; ignoring", { locale: candidate })
      }
    }
    var available = Object.keys(LOCALES)
    if (available.length === 0) {
      logError("no locale catalog is embedded in the page")
      return ""
    }
    return available[0]
  }

  function t(key, vars) {
    var table = LOCALES[state.lang] || {}
    var template = table[key]
    if (typeof template !== "string") {
      logError("missing message key", { key: key, locale: state.lang })
      return key
    }
    return template.replace(/\{(\w+)\}/g, function (match, name) {
      if (vars && Object.prototype.hasOwnProperty.call(vars, name)) {
        return String(vars[name])
      }
      return match
    })
  }

  function normalizePath(path) {
    if (!path) {
      return "/"
    }
    return path.charAt(0) === "/" ? path : "/" + path
  }

  function serviceUrl(protocol, host, port, path) {
    return protocol + "://" + host + ":" + port + normalizePath(path)
  }

  function hostAddresses(host) {
    var addresses = []
    if (host.magicDns) {
      addresses.push(host.magicDns)
    }
    Object.keys(host.overlays || {}).forEach(function (network) {
      var overlay = host.overlays[network]
      if (overlay && overlay.ip) {
        addresses.push(overlay.ip)
      }
    })
    return addresses.map(function (address) {
      return String(address).toLowerCase()
    })
  }

  function hostMatchesAddress(hostKey, hostname) {
    var host = DATA.hosts[hostKey]
    if (!host || !hostname) {
      return false
    }
    return hostAddresses(host).indexOf(hostname.toLowerCase()) !== -1
  }

  function detectHostByAddress(hostname) {
    if (!hostname) {
      return null
    }
    // Prefer the host this page was generated for when an address is shared,
    // then fall back to the first exact overlay or MagicDNS match.
    if (hostMatchesAddress(DATA.servedHost, hostname)) {
      return DATA.servedHost
    }
    var keys = Object.keys(DATA.hosts)
    for (var i = 0; i < keys.length; i += 1) {
      if (hostMatchesAddress(keys[i], hostname)) {
        return keys[i]
      }
    }
    return null
  }

  function resolveView() {
    var candidates = [queryParam("host"), readStorage(STORAGE_HOST)]
    for (var i = 0; i < candidates.length; i += 1) {
      var candidate = candidates[i]
      if (candidate && Object.prototype.hasOwnProperty.call(DATA.hosts, candidate)) {
        return candidate
      }
      if (candidate) {
        logWarning("unknown host key; ignoring", { host: candidate })
      }
    }
    return detectHostByAddress(window.location.hostname) || DATA.servedHost
  }

  function isLocalHostname(hostname) {
    return (
      hostname === "localhost" ||
      hostname === "127.0.0.1" ||
      hostname === "::1" ||
      hostname === "[::1]"
    )
  }

  function isWindowsClient() {
    return /windows/i.test(window.navigator.userAgent)
  }

  function isTailscaleAddress(hostname) {
    var parts = hostname.split(".")
    if (parts.length !== 4) {
      return false
    }
    var first = Number(parts[0])
    var second = Number(parts[1])
    return first === 100 && second >= 64 && second <= 127
  }

  function parseIpv4(value) {
    var parts = String(value).split(".")
    if (parts.length !== 4) {
      return null
    }
    var octets = parts.map(function (part) {
      var number = Number(part)
      if (!Number.isInteger(number) || number < 0 || number > 255) {
        return null
      }
      return number
    })
    if (octets.indexOf(null) !== -1) {
      return null
    }
    return octets[0] * 16777216 + octets[1] * 65536 + octets[2] * 256 + octets[3]
  }

  function ipv4MatchesPrefix(address, network, prefixLength) {
    var addressValue = parseIpv4(address)
    var networkValue = parseIpv4(network)
    if (addressValue === null || networkValue === null) {
      return false
    }
    if (!Number.isInteger(prefixLength) || prefixLength < 0 || prefixLength > 32) {
      return false
    }
    if (prefixLength === 0) {
      return true
    }
    var block = Math.pow(2, 32 - prefixLength)
    return Math.floor(addressValue / block) === Math.floor(networkValue / block)
  }

  function detectEnvironment() {
    var hostname = window.location.hostname.toLowerCase()
    var served = DATA.hosts[DATA.servedHost]

    if (isLocalHostname(hostname)) {
      if (served && served.kind === "wsl" && isWindowsClient()) {
        return "wsl-windows"
      }
      return "local"
    }

    if (isTailscaleAddress(hostname)) {
      return "tailscale"
    }

    var keys = Object.keys(DATA.hosts)
    for (var i = 0; i < keys.length; i += 1) {
      var host = DATA.hosts[keys[i]]
      if (host.magicDns && hostname === host.magicDns.toLowerCase()) {
        return "tailscale"
      }
      var overlays = host.overlays || {}
      var overlayNames = Object.keys(overlays)
      for (var j = 0; j < overlayNames.length; j += 1) {
        var overlay = overlays[overlayNames[j]]
        if (!overlay || !overlay.ip) {
          continue
        }
        if (
          hostname === String(overlay.ip).toLowerCase() ||
          ipv4MatchesPrefix(hostname, overlay.ip, overlay.prefixLength)
        ) {
          state.overlayNetwork = overlayNames[j]
          return overlayNames[j] === "tailscale" ? "tailscale" : "overlay"
        }
      }
    }

    return "external"
  }

  function available(label, url, extra) {
    return Object.assign({ label: label, url: url, status: "available" }, extra || {})
  }

  function conditional(label, url, reason, extra) {
    return Object.assign(
      { label: label, url: url, status: "conditional", reason: reason },
      extra || {}
    )
  }

  function unavailable(label, reason) {
    return { label: label, url: null, status: "unavailable", reason: reason }
  }

  function buildAccessModes(hostKey, service) {
    var host = DATA.hosts[hostKey]
    var path = normalizePath(service.path)
    var protocol = service.protocol || "http"
    var localUrl = serviceUrl(protocol, "localhost", service.port, path)
    var served = hostKey === DATA.servedHost
    var localEnv = state.env === "local" || state.env === "wsl-windows"
    var loopback = service.bind === "127.0.0.1" || service.bind === "::1"
    var modes = []

    if (service.forwardPort && hostKey !== DATA.servedHost) {
      // The page host forwards this remote endpoint to a local port. On the
      // page host that port is the reachable localhost entry; from any other
      // machine the forward does not exist.
      var forwardUrl = serviceUrl(protocol, "localhost", service.forwardPort, path)
      if (localEnv) {
        modes.push(
          available(t("mode.forwarded"), forwardUrl, {
            hint: t("mode.forwardedHint", { host: DATA.servedHost }),
          })
        )
      } else {
        modes.push(unavailable(t("mode.forwarded"), t("reason.localOnly")))
      }
    } else if (served && localEnv) {
      modes.push(available(t("mode.localhost"), localUrl))
    } else if (served) {
      modes.push(conditional(t("mode.localhost"), localUrl, t("reason.localOnly")))
    } else {
      modes.push(unavailable(t("mode.localhost"), t("reason.remoteHost", { host: hostKey })))
    }

    var overlays = host.overlays || {}
    var overlayNames = Object.keys(overlays)
    var tailscale = overlays.tailscale || null

    if (overlayNames.length === 0) {
      // No registered overlay: the host has no cross-host path at all.
      modes.push(unavailable(t("mode.overlayGeneric"), t("reason.noOverlay")))
    } else {
      if (!tailscale) {
        modes.push(unavailable(t("mode.tailscale"), t("reason.noTailscale")))
      } else if (loopback) {
        modes.push(unavailable(t("mode.tailscale"), t("reason.loopbackOnly")))
      } else {
        var tailscaleUrl = serviceUrl(protocol, tailscale.ip, service.port, path)
        var tailscaleHint = host.magicDns ? null : t("reason.noMagicDns")
        if (state.env === "tailscale") {
          modes.push(available(t("mode.tailscale"), tailscaleUrl, { hint: tailscaleHint }))
        } else {
          modes.push(
            conditional(t("mode.tailscale"), tailscaleUrl, t("reason.needsTailscale"), {
              hint: tailscaleHint,
            })
          )
        }
      }

      if (host.magicDns) {
        if (loopback) {
          modes.push(unavailable(t("mode.magicdns"), t("reason.loopbackOnly")))
        } else {
          var magicDnsUrl = serviceUrl(protocol, host.magicDns, service.port, path)
          if (state.env === "tailscale") {
            modes.push(available(t("mode.magicdns"), magicDnsUrl))
          } else {
            modes.push(conditional(t("mode.magicdns"), magicDnsUrl, t("reason.needsTailscale")))
          }
        }
      }

      overlayNames
        .filter(function (name) {
          return name !== "tailscale"
        })
        .forEach(function (name) {
          var networkLabel = t("network." + name)
          var modeLabel = t("mode.overlay", { network: networkLabel })
          if (loopback) {
            modes.push(unavailable(modeLabel, t("reason.loopbackOnly")))
            return
          }
          var url = serviceUrl(protocol, overlays[name].ip, service.port, path)
          if (state.env === "overlay" && state.overlayNetwork === name) {
            modes.push(available(modeLabel, url))
          } else {
            modes.push(
              conditional(modeLabel, url, t("reason.needsOverlay", { network: networkLabel }))
            )
          }
        })
    }

    if (host.kind === "wsl") {
      if (!served) {
        modes.push(unavailable(t("mode.wslWindows"), t("reason.remoteHost", { host: hostKey })))
      } else if (localEnv) {
        modes.push(available(t("mode.wslWindows"), localUrl))
      } else {
        modes.push(conditional(t("mode.wslWindows"), localUrl, t("reason.wslWindows")))
      }
    }

    return modes
  }

  function tagLabel(tag) {
    var key = "tag." + tag
    var table = LOCALES[state.lang] || {}
    if (typeof table[key] !== "string") {
      return tag
    }
    return t(key)
  }

  function noteText(service) {
    if (!service.note) {
      return null
    }
    var key = "note." + service.note
    var table = LOCALES[state.lang] || {}
    if (typeof table[key] !== "string") {
      return null
    }
    return table[key]
  }

  function matchesFilter(service) {
    if (!state.filter) {
      return true
    }
    var needle = state.filter.toLowerCase()
    var haystack = [
      service.name,
      service.label,
      String(service.port),
      (service.tags || []).map(tagLabel).join(" "),
      noteText(service) || "",
    ]
      .join(" ")
      .toLowerCase()
    return haystack.indexOf(needle) !== -1
  }

  function renderMode(mode) {
    var value
    if (mode.url && mode.status !== "unavailable") {
      value = '<a class="url" href="' + escapeHtml(mode.url) + '">' + escapeHtml(mode.url) + "</a>"
    } else {
      value = '<span class="url muted">' + escapeHtml(t("mode.unavailableValue")) + "</span>"
    }
    var badge =
      '<span class="status status-' +
      mode.status +
      '">' +
      escapeHtml(t("status." + mode.status)) +
      "</span>"
    var reason = mode.reason ? '<span class="reason">' + escapeHtml(mode.reason) + "</span>" : ""
    var hint = mode.hint ? '<span class="hint">' + escapeHtml(mode.hint) + "</span>" : ""
    return (
      '<div class="mode">' +
      '<span class="mode-label">' +
      escapeHtml(mode.label) +
      "</span>" +
      value +
      badge +
      reason +
      hint +
      "</div>"
    )
  }

  function renderService(hostKey, service) {
    var tags = (service.tags || [])
      .map(function (tag) {
        return '<span class="tag">' + escapeHtml(tagLabel(tag)) + "</span>"
      })
      .join("")
    var note = noteText(service)
    var modes = buildAccessModes(hostKey, service).map(renderMode).join("")
    return (
      '<article class="service">' +
      '<div class="service-head">' +
      "<h3>" +
      escapeHtml(service.label || service.name) +
      "</h3>" +
      '<span class="port">' +
      escapeHtml(t("service.port", { port: service.port })) +
      "</span>" +
      "</div>" +
      (tags ? '<div class="tags">' + tags + "</div>" : "") +
      (note ? '<p class="note">' + escapeHtml(note) + "</p>" : "") +
      '<div class="modes">' +
      modes +
      "</div>" +
      "</article>"
    )
  }

  function renderHost(hostKey, host) {
    var services = host.services.filter(matchesFilter)
    if (state.filter && services.length === 0) {
      return ""
    }
    var html = []
    html.push('<section class="host" data-host="' + escapeHtml(hostKey) + '">')
    html.push('<header class="host-header">')
    html.push('<div class="host-title">')
    html.push("<h2>" + escapeHtml(hostKey) + "</h2>")
    html.push('<span class="kind">' + escapeHtml(t("host.kind." + host.kind)) + "</span>")
    if (hostKey === state.view) {
      html.push('<span class="badge current">' + escapeHtml(t("host.current")) + "</span>")
    }
    if (hostKey === DATA.servedHost) {
      html.push('<span class="badge served">' + escapeHtml(t("host.served")) + "</span>")
    }
    if (!host.crossHostReachable) {
      html.push(
        '<span class="badge unreachable">' + escapeHtml(t("host.crossHostUnreachable")) + "</span>"
      )
    }
    html.push("</div>")
    html.push(
      '<div class="host-count">' +
        escapeHtml(t("host.services", { count: host.services.length })) +
        "</div>"
    )
    html.push("</header>")
    if (!host.crossHostReachable) {
      html.push(
        '<p class="host-note unreachable">' +
          escapeHtml(t("host.crossHostUnreachableNote")) +
          "</p>"
      )
    }
    if (host.kind === "wsl") {
      html.push('<p class="host-note">' + escapeHtml(t("host.wslNote")) + "</p>")
    }
    if (services.length === 0) {
      html.push(
        '<p class="empty">' +
          escapeHtml(t(state.filter ? "empty.noResults" : "empty.noServices")) +
          "</p>"
      )
    } else {
      html.push('<div class="service-grid">')
      services.forEach(function (service) {
        html.push(renderService(hostKey, service))
      })
      html.push("</div>")
    }
    html.push("</section>")
    return html.join("")
  }

  function render() {
    var app = document.getElementById("app")
    var hostKeys = Object.keys(DATA.hosts)
    var ordered = [state.view].concat(
      hostKeys.filter(function (key) {
        return key !== state.view
      })
    )
    var hostOptions = hostKeys
      .map(function (key) {
        var host = DATA.hosts[key]
        var label = t("host.option", { host: key, kind: t("host.kind." + host.kind) })
        var selected = key === state.view ? " selected" : ""
        return (
          '<option value="' +
          escapeHtml(key) +
          '"' +
          selected +
          ">" +
          escapeHtml(label) +
          "</option>"
        )
      })
      .join("")
    var languageOptions = DATA.languages
      .map(function (lang) {
        var table = LOCALES[lang] || {}
        var label = typeof table["language.name"] === "string" ? table["language.name"] : lang
        var selected = lang === state.lang ? " selected" : ""
        return (
          '<option value="' +
          escapeHtml(lang) +
          '"' +
          selected +
          ">" +
          escapeHtml(label) +
          "</option>"
        )
      })
      .join("")

    document.documentElement.lang = state.lang
    document.title = t("page.title")

    var html = []
    html.push('<header class="page-header">')
    html.push('<div class="titles">')
    html.push("<h1>" + escapeHtml(t("page.title")) + "</h1>")
    html.push("<p>" + escapeHtml(t("page.subtitle", { hostCount: hostKeys.length })) + "</p>")
    html.push(
      '<p class="served">' + escapeHtml(t("page.servedFrom", { host: DATA.servedHost })) + "</p>"
    )
    html.push("</div>")
    html.push('<div class="controls">')
    html.push(
      '<label><span class="control-label">' +
        escapeHtml(t("nav.hostView")) +
        '</span><select id="host-select">' +
        hostOptions +
        "</select></label>"
    )
    html.push(
      '<label><span class="control-label">' +
        escapeHtml(t("nav.language")) +
        '</span><select id="lang-select">' +
        languageOptions +
        "</select></label>"
    )
    html.push(
      '<label class="search"><span class="control-label">' +
        escapeHtml(t("nav.search")) +
        '</span><input id="search-input" type="search" value="' +
        escapeHtml(state.filter) +
        '" /></label>'
    )
    html.push("</div>")
    html.push("</header>")

    var rendered = 0
    ordered.forEach(function (key) {
      var host = DATA.hosts[key]
      var section = renderHost(key, host)
      if (section) {
        rendered += 1
        html.push(section)
      }
    })
    if (rendered === 0) {
      html.push('<p class="empty">' + escapeHtml(t("empty.noResults")) + "</p>")
    }

    app.innerHTML = html.join("")
    bindControls()
  }

  function bindControls() {
    var hostSelect = document.getElementById("host-select")
    var langSelect = document.getElementById("lang-select")
    var search = document.getElementById("search-input")

    if (hostSelect) {
      hostSelect.addEventListener("change", function (event) {
        state.view = event.target.value
        writeStorage(STORAGE_HOST, state.view)
        render()
      })
    }

    if (langSelect) {
      langSelect.addEventListener("change", function (event) {
        state.lang = event.target.value
        writeStorage(STORAGE_LANG, state.lang)
        render()
      })
    }

    if (search) {
      search.addEventListener("input", function (event) {
        state.filter = event.target.value
        render()
        var next = document.getElementById("search-input")
        if (next) {
          next.focus()
          next.setSelectionRange(next.value.length, next.value.length)
        }
      })
    }
  }

  state.lang = resolveLanguage()
  state.env = detectEnvironment()
  state.view = resolveView()
  render()
})()
