import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const overallResponseTime = new Trend('overall_response_time');
const successfulRequests = new Counter('successful_requests');
const failedRequests = new Counter('failed_requests');

// Test configuration
export const options = {
  stages: [
    { duration: '1m', target: 5 },   // Ramp up to 5 users
    { duration: '3m', target: 5 },   // Stay at 5 users
    { duration: '1m', target: 10 },  // Ramp up to 10 users
    { duration: '3m', target: 10 },  // Stay at 10 users
    { duration: '1m', target: 15 },  // Ramp up to 15 users
    { duration: '3m', target: 15 },  // Stay at 15 users
    { duration: '1m', target: 0 },   // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests should be below 500ms
    http_req_failed: ['rate<0.1'],    // Error rate should be less than 10%
    'overall_response_time': ['p(95)<400'],
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

const USER_IDS = [
  'user-001',
  'user-002',
  'user-003',
  'user-004',
  'user-005',
  'user-006',
  'user-007',
  'user-008',
  'user-009',
  'user-010'
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

// Helper functions
function getRandomItem(array) {
  return array[Math.floor(Math.random() * array.length)];
}

function getRandomProductId() {
  return getRandomItem(PRODUCT_IDS);
}

function getRandomUserId() {
  return getRandomItem(USER_IDS);
}

function getRandomSearchTerm() {
  return getRandomItem(SEARCH_TERMS);
}

function getRandomQuantity() {
  return Math.floor(Math.random() * 5) + 1; // 1-5 items
}

function randomDelay() {
  sleep(Math.random() * 2 + 1); // Random delay between 1-3 seconds
}

function generateCartItem(productId, quantity) {
  return {
    product_id: productId,
    quantity: quantity
  };
}

// Test scenarios
function testCatalogService(baseUrl) {
  const catalogServiceUrl = `${baseUrl}/api/products`;
  
  // Get all products
  const getAllProductsResponse = http.get(`${catalogServiceUrl}`);
  
  check(getAllProductsResponse, {
    'catalog - get all products status is 200': (r) => r.status === 200,
    'catalog - get all products response time < 500ms': (r) => r.timings.duration < 500,
  });
  
  overallResponseTime.add(getAllProductsResponse.timings.duration);
  
  if (getAllProductsResponse.status === 200) {
    successfulRequests.add(1);
  } else {
    failedRequests.add(1);
    errorRate.add(1);
  }
  
  // Get product by ID
  const productId = getRandomProductId();
  const getProductResponse = http.get(`${catalogServiceUrl}/${productId}`);
  
  check(getProductResponse, {
    'catalog - get product by id status is 200': (r) => r.status === 200,
    'catalog - get product by id response time < 200ms': (r) => r.timings.duration < 200,
  });
  
  overallResponseTime.add(getProductResponse.timings.duration);
  
  if (getProductResponse.status === 200) {
    successfulRequests.add(1);
  } else {
    failedRequests.add(1);
    errorRate.add(1);
  }
  
  // Search products
  const searchTerm = getRandomSearchTerm();
  const searchResponse = http.get(`${catalogServiceUrl}/search?q=${searchTerm}`);
  
  check(searchResponse, {
    'catalog - search products status is 200': (r) => r.status === 200,
    'catalog - search products response time < 400ms': (r) => r.timings.duration < 400,
  });
  
  overallResponseTime.add(searchResponse.timings.duration);
  
  if (searchResponse.status === 200) {
    successfulRequests.add(1);
  } else {
    failedRequests.add(1);
    errorRate.add(1);
  }
}

function testCartService(baseUrl) {
  const cartServiceUrl = `${baseUrl}/api/cart`;
  const userId = getRandomUserId();
  
  // Get cart
  const getCartResponse = http.get(`${cartServiceUrl}/${userId}`);
  
  check(getCartResponse, {
    'cart - get cart status is 200': (r) => r.status === 200,
    'cart - get cart response time < 200ms': (r) => r.timings.duration < 200,
  });
  
  overallResponseTime.add(getCartResponse.timings.duration);
  
  if (getCartResponse.status === 200) {
    successfulRequests.add(1);
  } else {
    failedRequests.add(1);
    errorRate.add(1);
  }
  
  // Add item to cart
  const productId = getRandomProductId();
  const quantity = getRandomQuantity();
  const cartItem = generateCartItem(productId, quantity);
  
  const addItemResponse = http.post(`${cartServiceUrl}/${userId}/items`, JSON.stringify(cartItem), {
    headers: {
      'Content-Type': 'application/json',
    },
  });
  
  check(addItemResponse, {
    'cart - add item status is 200': (r) => r.status === 200,
    'cart - add item response time < 400ms': (r) => r.timings.duration < 400,
  });
  
  overallResponseTime.add(addItemResponse.timings.duration);
  
  if (addItemResponse.status === 200) {
    successfulRequests.add(1);
  } else {
    failedRequests.add(1);
    errorRate.add(1);
  }
  
  // Get cart total
  const getCartTotalResponse = http.get(`${cartServiceUrl}/${userId}/total`);
  
  check(getCartTotalResponse, {
    'cart - get cart total status is 200': (r) => r.status === 200,
    'cart - get cart total response time < 300ms': (r) => r.timings.duration < 300,
  });
  
  overallResponseTime.add(getCartTotalResponse.timings.duration);
  
  if (getCartTotalResponse.status === 200) {
    successfulRequests.add(1);
  } else {
    failedRequests.add(1);
    errorRate.add(1);
  }
  
  // Occasionally remove item or clear cart
  if (Math.random() < 0.3) {
    const removeItemResponse = http.del(`${cartServiceUrl}/${userId}/items/${productId}`);
    
    check(removeItemResponse, {
      'cart - remove item status is 200': (r) => r.status === 200,
      'cart - remove item response time < 300ms': (r) => r.timings.duration < 300,
    });
    
    overallResponseTime.add(removeItemResponse.timings.duration);
    
    if (removeItemResponse.status === 200) {
      successfulRequests.add(1);
    } else {
      failedRequests.add(1);
      errorRate.add(1);
    }
  }
}

function testFrontendService(baseUrl) {
  // Test frontend endpoints
  const frontendResponse = http.get(`${baseUrl}/`);
  
  check(frontendResponse, {
    'frontend - homepage status is 200': (r) => r.status === 200,
    'frontend - homepage response time < 1000ms': (r) => r.timings.duration < 1000,
  });
  
  overallResponseTime.add(frontendResponse.timings.duration);
  
  if (frontendResponse.status === 200) {
    successfulRequests.add(1);
  } else {
    failedRequests.add(1);
    errorRate.add(1);
  }
  
  // Test static assets
  const staticResponse = http.get(`${baseUrl}/static/css/main.css`);
  
  check(staticResponse, {
    'frontend - static assets status is 200': (r) => r.status === 200,
    'frontend - static assets response time < 500ms': (r) => r.timings.duration < 500,
  });
  
  overallResponseTime.add(staticResponse.timings.duration);
  
  if (staticResponse.status === 200) {
    successfulRequests.add(1);
  } else {
    failedRequests.add(1);
    errorRate.add(1);
  }
}

export default function () {
  const baseUrl = __ENV.BASE_URL || 'http://localhost:8080';
  
  // Randomly choose which service to test
  const serviceChoice = Math.random();
  
  if (serviceChoice < 0.4) {
    // 40% chance to test catalog service
    testCatalogService(baseUrl);
  } else if (serviceChoice < 0.8) {
    // 40% chance to test cart service
    testCartService(baseUrl);
  } else {
    // 20% chance to test frontend service
    testFrontendService(baseUrl);
  }
  
  randomDelay();
}

// Setup function
export function setup() {
  console.log('Starting Comprehensive Load Test');
  console.log(`Base URL: ${__ENV.BASE_URL || 'http://localhost:8080'}`);
  console.log('Test will run for 13 minutes with varying load');
  console.log('Testing: Catalog Service (40%), Cart Service (40%), Frontend (20%)');
}

// Teardown function
export function teardown(data) {
  console.log('Comprehensive Load Test completed');
  console.log('Check the results for performance insights');
} 