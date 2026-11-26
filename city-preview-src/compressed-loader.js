(() => {
  if (!('DecompressionStream' in window)) return;
  const originalFetch = window.fetch.bind(window);
  window.fetch = async (input, init) => {
    const url = new URL(input instanceof Request ? input.url : String(input), document.baseURI);
    if (url.origin !== location.origin || !url.pathname.endsWith('/index.wasm')) return originalFetch(input, init);
    const compressed = new URL(url); compressed.pathname += '.gz';
    const response = await originalFetch(compressed, init);
    if (!response.ok || !response.body) return originalFetch(input, init);
    const body = /gzip/i.test(response.headers.get('Content-Encoding') || '') ? response.body : response.body.pipeThrough(new DecompressionStream('gzip'));
    window.cityCompressedEngine = true;
    return new Response(body, {status: 200, headers: {'Content-Type': 'application/wasm'}});
  };
})();
