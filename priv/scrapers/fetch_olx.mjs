import { gotScraping } from 'got-scraping';

// Prevent unhandled EPIPE when Elixir closes the stdout pipe
process.stdout.on('error', (err) => {
  if (err.code === 'EPIPE') {
    process.exit(0);
  }
});

function resolveProxyUrl(raw) {
  if (!raw || raw.trim() === '') return null;
  const trimmed = raw.trim();
  if (
    trimmed.startsWith('http://') ||
    trimmed.startsWith('https://') ||
    trimmed.startsWith('socks5://') ||
    trimmed.startsWith('socks4://')
  ) {
    return trimmed;
  }
  // If user provided a direct ScraperAPI key (e.g. 32-char hex string)
  return `http://scraperapi.country_code=br:${trimmed}@proxy-server.scraperapi.com:8001`;
}

async function main() {
  const targetUrl = process.argv[2];
  if (!targetUrl) {
    console.error('URL parameter is required');
    process.exit(1);
  }

  const rawProxy =
    process.env.SCRAPER_PROXY_URL ||
    process.env.SCRAPERAPI_KEY ||
    process.env.HTTP_PROXY ||
    process.env.HTTPS_PROXY;

  const proxyUrl = resolveProxyUrl(rawProxy);

  const requestOptions = {
    url: targetUrl,
    timeout: {
      request: proxyUrl ? 15000 : 10000
    },
    headers: {
      'referer': 'https://www.google.com.br/'
    },
    headerGeneratorOptions: {
      browsers: [
        { name: 'chrome', minVersion: 120, maxVersion: 130 },
        { name: 'firefox', minVersion: 120 }
      ],
      devices: ['desktop'],
      locales: ['pt-BR', 'pt'],
      operatingSystems: ['windows', 'linux', 'macos']
    }
  };

  if (proxyUrl) {
    requestOptions.proxyUrl = proxyUrl;
  }

  try {
    const response = await gotScraping(requestOptions);

    if (response.statusCode === 200 && response.body && response.body.length > 0) {
      // Ensure all data is flushed to stdout before exiting
      process.stdout.write(response.body, (err) => {
        if (err) {
          process.exit(1);
        } else {
          process.exit(0);
        }
      });
    } else {
      console.error(`HTTP_${response.statusCode}`);
      process.exit(1);
    }
  } catch (err) {
    console.error(`ERROR_${err.message}`);
    process.exit(1);
  }
}

main();
