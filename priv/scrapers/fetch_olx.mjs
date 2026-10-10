import { gotScraping } from 'got-scraping';

// Prevent unhandled EPIPE when Elixir closes the stdout pipe
process.stdout.on('error', (err) => {
  if (err.code === 'EPIPE') {
    process.exit(0);
  }
});

async function main() {
  const targetUrl = process.argv[2];
  if (!targetUrl) {
    console.error('URL parameter is required');
    process.exit(1);
  }

  const proxyUrl = process.env.SCRAPER_PROXY_URL || process.env.HTTP_PROXY || process.env.HTTPS_PROXY;

  const requestOptions = {
    url: targetUrl,
    timeout: {
      request: 10000
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

  if (proxyUrl && proxyUrl.trim() !== '') {
    requestOptions.proxyUrl = proxyUrl.trim();
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
