// Keep durable storage paths in records; authorize short-lived display URLs only.
// This also supports historical public URLs after the bucket becomes private.
export function privateStoragePath(value, projectUrl) {
  try {
    const url = new URL(value)
    if (url.origin !== new URL(projectUrl).origin) return null
    const match = url.pathname.match(/^\/storage\/v1\/object\/public\/(daily-instructions|technical-job-files|shift-documents)\/(.+)$/)
    return match ? { bucket: match[1], path: decodeURIComponent(match[2]) } : null
  } catch { return null }
}

export function installPrivateFileLinks(client, projectUrl) {
  const cache = new Map()
  const inFlight = new WeakMap()
  const sourceUrls = new WeakMap()
  const attributes = { A: 'href', IMG: 'src', IFRAME: 'src', OBJECT: 'data', SOURCE: 'src', VIDEO: 'src' }
  async function authorize(element) {
    const attribute = attributes[element.tagName]
    if (!attribute) return
    const original = element.getAttribute(attribute)
    const originalFile = privateStoragePath(original, projectUrl)
    if (originalFile) sourceUrls.set(element, { original, displayed: original })
    const previous = sourceUrls.get(element)
    const file = originalFile || (previous?.displayed === original ? privateStoragePath(previous.original, projectUrl) : null)
    if (!file || inFlight.get(element) === original) return
    inFlight.set(element, original)
    try {
      const key = `${file.bucket}/${file.path}`
      let entry = cache.get(key)
      if (!entry || entry.until < Date.now()) {
        const { data, error } = await client.storage.from(file.bucket).createSignedUrl(file.path, 600)
        if (error || !data?.signedUrl) return
        entry = { url: data.signedUrl, until: Date.now() + 300000 }
        cache.set(key, entry)
      }
      if (element.getAttribute(attribute) === original && original !== entry.url) {
        sourceUrls.set(element, { original: previous?.original || original, displayed: entry.url })
        element.setAttribute(attribute, entry.url)
      }
    } finally { inFlight.delete(element) }
  }
  function scan(root) {
    if (root.nodeType !== 1) return
    authorize(root)
    root.querySelectorAll('a[href],img[src],iframe[src],object[data],source[src],video[src]').forEach(authorize)
  }
  const observer = new MutationObserver(records => {
    for (const record of records) {
      if (record.type === 'attributes') authorize(record.target)
      else record.addedNodes.forEach(scan)
    }
  })
  observer.observe(document.documentElement, { subtree: true, childList: true, attributes: true, attributeFilter: ['href', 'src', 'data'] })
  scan(document.documentElement)
  window.setInterval(() => scan(document.documentElement), 240000)
  return observer
}
