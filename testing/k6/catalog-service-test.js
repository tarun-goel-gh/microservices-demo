import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const catalogResponseTime = new Trend('catalog_response_time');
const productSearchTime = new Trend('product_search_time');
const productDetailTime = new Trend('product_detail_time');
const successfulRequests = new Counter('successful_requests');
const failedRequests = new Counter('failed_requests');

// Test configuration
export const options = {
  stages: [
    { duration: '2m', target: 10 },  // Ramp up to 10 users
    { duration: '5m', target: 10 },  // Stay at 10 users
    { duration: '2m', target: 20 },  // Ramp up to 20 users
    { duration: '5m', target: 20 },  // Stay at 20 users
    { duration: '2m', target: 0 },   // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests should be below 500ms
    http_req_failed: ['rate<0.1'],    // Error rate should be less than 10%
    'catalog_response_time': ['p(95)<300'],
    'product_search_time': ['p(95)<400'],
    'product_detail_time': ['p(95)<200'],
  },
};

// Test data
const PRODUCT_IDS = [
  'OLJCESPC7Z',
  '66VCHSJNUP',
  '1YMWWN1N4O',
  '2ZYFJ3GM2N',
  '0PUK6V6EV0',
  'LS4PSXUNUM',
  '9SIQT8TOJO',
  '6E92ZMYYFZ',
  'L9ECAV7KIM',
  '2LS3EF2PRP'
];

const SEARCH_TERMS = [
  'phone',
  'laptop',
  'camera',
  'watch',
  'speaker',
  'headphone',
  'tablet',
  'keyboard',
  'mouse',
  'monitor'
];

// Helper function to get random item from array
function getRandomItem(array) {
  return array[Math.floor(Math.random() * array.length)];
}

// Helper function to generate random product ID
function getRandomProductId() {
  return getRandomItem(PRODUCT_IDS);
}

// Helper function to generate random search term
function getRandomSearchTerm() {
  return getRandomItem(SEARCH_TERMS);
}

// Helper function to add random delay
function randomDelay() {
  sleep(Math.random() * 2 + 1); // Random delay between 1-3 seconds
}

export default function () {
  const baseUrl = __ENV.BASE_URL || 'http://localhost:8080';
  const catalogServiceUrl = `${baseUrl}/api/products`;
  
  // Test 1: Get all products
  const getAllProductsResponse = http.get(`${catalogServiceUrl}`);
  
  check(getAllProductsResponse, {
    'get all products status is 200': (r) => r.status === 200,
    'get all products response time < 500ms': (r) => r.timings.duration < 500,
    'get all products has products array': (r) => {
      try {
        const body = JSON.parse(r.body);
        return Array.isArray(body.products) && body.products.length > 0;
      } catch (e) {
        return false;
      }
    },
  });
  
  catalogResponseTime.add(getAllProductsResponse.timings.duration);
  
  if (getAllProductsResponse.status === 200) {
    successfulRequests.add(1);
  } else {
    failedRequests.add(1);
    errorRate.add(1);
  }
  
  randomDelay();
  
  // Test 2: Get product by ID
  const productId = getRandomProductId();
  const getProductResponse = http.get(`${catalogServiceUrl}/${productId}`);
  
  check(getProductResponse, {
    'get product by id status is 200': (r) => r.status === 200,
    'get product by id response time < 200ms': (r) => r.timings.duration < 200,
    'get product by id has product data': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.id && body.name && body.price_usd;
      } catch (e) {
        return false;
      }
    },
  });
  
  productDetailTime.add(getProductResponse.timings.duration);
  
  if (getProductResponse.status === 200) {
    successfulRequests.add(1);
  } else {
    failedRequests.add(1);
    errorRate.add(1);
  }
  
  randomDelay();
  
  // Test 3: Search products
  const searchTerm = getRandomSearchTerm();
  const searchResponse = http.get(`${catalogServiceUrl}/search?q=${searchTerm}`);
  
  check(searchResponse, {
    'search products status is 200': (r) => r.status === 200,
    'search products response time < 400ms': (r) => r.timings.duration < 400,
    'search products has results': (r) => {
      try {
        const body = JSON.parse(r.body);
        return Array.isArray(body.results);
      } catch (e) {
        return false;
      }
    },
  });
  
  productSearchTime.add(searchResponse.timings.duration);
  
  if (searchResponse.status === 200) {
    successfulRequests.add(1);
  } else {
    failedRequests.add(1);
    errorRate.add(1);
  }
  
  randomDelay();
  
  // Test 4: Get product categories
  const categoriesResponse = http.get(`${catalogServiceUrl}/categories`);
  
  check(categoriesResponse, {
    'get categories status is 200': (r) => r.status === 200,
    'get categories response time < 300ms': (r) => r.timings.duration < 300,
    'get categories has categories array': (r) => {
      try {
        const body = JSON.parse(r.body);
        return Array.isArray(body.categories);
      } catch (e) {
        return false;
      }
    },
  });
  
  catalogResponseTime.add(categoriesResponse.timings.duration);
  
  if (categoriesResponse.status === 200) {
    successfulRequests.add(1);
  } else {
    failedRequests.add(1);
    errorRate.add(1);
  }
  
  randomDelay();
  
  // Test 5: Get products by category
  const category = 'electronics'; // You can randomize this if you have multiple categories
  const categoryResponse = http.get(`${catalogServiceUrl}/category/${category}`);
  
  check(categoryResponse, {
    'get products by category status is 200': (r) => r.status === 200,
    'get products by category response time < 400ms': (r) => r.timings.duration < 400,
    'get products by category has products': (r) => {
      try {
        const body = JSON.parse(r.body);
        return Array.isArray(body.products);
      } catch (e) {
        return false;
      }
    },
  });
  
  catalogResponseTime.add(categoryResponse.timings.duration);
  
  if (categoryResponse.status === 200) {
    successfulRequests.add(1);
  } else {
    failedRequests.add(1);
    errorRate.add(1);
  }
  
  randomDelay();
}

// Setup function (runs once before the test)
export function setup() {
  console.log('Starting Catalog Service Performance Test');
  console.log(`Base URL: ${__ENV.BASE_URL || 'http://localhost:8080'}`);
  console.log('Test will run for 16 minutes with varying load');
}

// Teardown function (runs once after the test)
export function teardown(data) {
  console.log('Catalog Service Performance Test completed');
  console.log('Check the results for performance insights');
} 