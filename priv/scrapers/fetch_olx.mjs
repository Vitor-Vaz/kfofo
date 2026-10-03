import { gotScraping } from 'got-scraping';

async function main() {
  const targetUrl = process.argv[2];
  if (!targetUrl) {
    console.error('URL parameter is required');
    process.exit(1);
  }

  try {
    const response = await gotScraping({
      url: targetUrl,
      headerGeneratorOptions: {
        browsers: [{ name: 'chrome', minVersion: 120 }],
        devices: ['desktop'],
        locales: ['pt-BR', 'pt'],
        operatingSystems: ['linux', 'windows']
      }
    });

    if (response.statusCode === 200 && (response.body.includes('olx-adcard') || response.body.includes('__NEXT_DATA__'))) {
      process.stdout.write(response.body);
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
