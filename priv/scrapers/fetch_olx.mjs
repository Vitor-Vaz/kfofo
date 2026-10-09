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

  try {
    const response = await gotScraping({
      url: targetUrl,
      timeout: {
        request: 10000
      },
      headers: {
        'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'accept-language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
        'cache-control': 'no-cache',
        'pragma': 'no-cache',
        'sec-ch-ua': '"Google Chrome";v="123", "Not:A-Brand";v="8", "Chromium";v="123"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"Linux"',
        'sec-fetch-dest': 'document',
        'sec-fetch-mode': 'navigate',
        'sec-fetch-site': 'none',
        'sec-fetch-user': '?1',
        'upgrade-insecure-requests': '1'
      },
      headerGeneratorOptions: {
        browsers: [{ name: 'chrome', minVersion: 120 }],
        devices: ['desktop'],
        locales: ['pt-BR', 'pt'],
        operatingSystems: ['linux', 'windows']
      }
    });

    if (response.statusCode === 200 && response.body && response.body.length > 0) {
      process.stdout.write(response.body);
      process.exit(0);
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
