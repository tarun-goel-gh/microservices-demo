import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const cartResponseTime = new Trend('cart_response_time');
const addItemTime = new Trend('add_item_time');
const getCartTime = new Trend('get_cart_time');
const removeItemTime = new Trend('remove_item_time');
const clearCartTime = new Trend('clear_cart_time');
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
    'cart_response_time': ['p(95)<300'],
    'add_item_time': ['p(95)<400'],
    'get_cart_time': ['p(95)<200'],
    'remove_item_time': ['p(95)<300'],
    'clear_cart_time': ['p(95)<200'],
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

// Helper function to get random item from array
function getRandomItem(array) {
  return array[Math.floor(Math.random() * array.length)];
}

// Helper function to generate random product ID
function getRandomProductId() {
  return getRandomItem(PRODUCT_IDS);
}

// Helper function to generate random user ID
function getRandomUserId() {
  return getRandomItem(USER_IDS);
}

// Helper function to generate random quantity
function getRandomQuantity() {
  return Math.floor(Math.random() * 5) + 1; // 1-5 items
}

// Helper function to add random delay
function randomDelay() {
  sleep(Math.random() * 2 + 1); // Random delay between 1-3 seconds
}

// Helper function to generate cart item payload
function generateCartItem(productId, quantity) {
  return {
    product_id: productId,
    quantity: quantity
  };
}

export default function () {
  const baseUrl = __ENV.BASE_URL || 'http://localhost:8080';
  const cartServiceUrl = `${baseUrl}/api/cart`;
  const userId = getRandomUserId();
  
  // Test 1: Get cart (empty or with items)
  const getCartResponse = http.get(`${cartServiceUrl}/${userId}`);
  
  check(getCartResponse, {
    'get cart status is 200': (r) => r.status === 200,
    'get cart response time < 200ms': (r) => r.timings.duration < 200,
    'get cart has valid response': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.user_id === userId && Array.isArray(body.items);
      } catch (e) {
        return false;
      }
    },
  });
  
  getCartTime.add(getCartResponse.timings.duration);
  
  if (getCartResponse.status === 200) {
    successfulRequests.add(1);
  } else {
    failedRequests.add(1);
    errorRate.add(1);
  }
  
  randomDelay();
  
  // Test 2: Add item to cart
  const productId = getRandomProductId();
  const quantity = getRandomQuantity();
  const cartItem = generateCartItem(productId, quantity);
  
  const addItemResponse = http.post(`${cartServiceUrl}/${userId}/items`, JSON.stringify(cartItem), {
    headers: {
      'Content-Type': 'application/json',
    },
  });
  
  check(addItemResponse, {
    'add item status is 200': (r) => r.status === 200,
    'add item response time < 400ms': (r) => r.timings.duration < 400,
    'add item has valid response': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.user_id === userId && Array.isArray(body.items);
      } catch (e) {
        return false;
      }
    },
  });
  
  addItemTime.add(addItemResponse.timings.duration);
  
  if (addItemResponse.status === 200) {
    successfulRequests.add(1);
  } else {
    failedRequests.add(1);
    errorRate.add(1);
  }
  
  randomDelay();
  
  // Test 3: Get cart again (should have items now)
  const getCartWithItemsResponse = http.get(`${cartServiceUrl}/${userId}`);
  
  check(getCartWithItemsResponse, {
    'get cart with items status is 200': (r) => r.status === 200,
    'get cart with items response time < 200ms': (r) => r.timings.duration < 200,
    'get cart with items has items': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.user_id === userId && body.items.length > 0;
      } catch (e) {
        return false;
      }
    },
  });
  
  getCartTime.add(getCartWithItemsResponse.timings.duration);
  
  if (getCartWithItemsResponse.status === 200) {
    successfulRequests.add(1);
  } else {
    failedRequests.add(1);
    errorRate.add(1);
  }
  
  randomDelay();
  
  // Test 4: Update item quantity
  const newQuantity = getRandomQuantity();
  const updateItemPayload = generateCartItem(productId, newQuantity);
  
  const updateItemResponse = http.put(`${cartServiceUrl}/${userId}/items/${productId}`, JSON.stringify(updateItemPayload), {
    headers: {
      'Content-Type': 'application/json',
    },
  });
  
  check(updateItemResponse, {
    'update item status is 200': (r) => r.status === 200,
    'update item response time < 300ms': (r) => r.timings.duration < 300,
    'update item has valid response': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.user_id === userId;
      } catch (e) {
        return false;
      }
    },
  });
  
  cartResponseTime.add(updateItemResponse.timings.duration);
  
  if (updateItemResponse.status === 200) {
    successfulRequests.add(1);
  } else {
    failedRequests.add(1);
    errorRate.add(1);
  }
  
  randomDelay();
  
  // Test 5: Remove item from cart
  const removeItemResponse = http.del(`${cartServiceUrl}/${userId}/items/${productId}`);
  
  check(removeItemResponse, {
    'remove item status is 200': (r) => r.status === 200,
    'remove item response time < 300ms': (r) => r.timings.duration < 300,
    'remove item has valid response': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.user_id === userId;
      } catch (e) {
        return false;
      }
    },
  });
  
  removeItemTime.add(removeItemResponse.timings.duration);
  
  if (removeItemResponse.status === 200) {
    successfulRequests.add(1);
  } else {
    failedRequests.add(1);
    errorRate.add(1);
  }
  
  randomDelay();
  
  // Test 6: Add multiple items to cart
  const numItems = Math.floor(Math.random() * 3) + 1; // 1-3 items
  for (let i = 0; i < numItems; i++) {
    const itemProductId = getRandomProductId();
    const itemQuantity = getRandomQuantity();
    const itemPayload = generateCartItem(itemProductId, itemQuantity);
    
    const addMultipleItemResponse = http.post(`${cartServiceUrl}/${userId}/items`, JSON.stringify(itemPayload), {
      headers: {
        'Content-Type': 'application/json',
      },
    });
    
    check(addMultipleItemResponse, {
      'add multiple items status is 200': (r) => r.status === 200,
      'add multiple items response time < 400ms': (r) => r.timings.duration < 400,
    });
    
    addItemTime.add(addMultipleItemResponse.timings.duration);
    
    if (addMultipleItemResponse.status === 200) {
      successfulRequests.add(1);
    } else {
      failedRequests.add(1);
      errorRate.add(1);
    }
    
    sleep(0.5); // Small delay between multiple items
  }
  
  randomDelay();
  
  // Test 7: Get cart total
  const getCartTotalResponse = http.get(`${cartServiceUrl}/${userId}/total`);
  
  check(getCartTotalResponse, {
    'get cart total status is 200': (r) => r.status === 200,
    'get cart total response time < 300ms': (r) => r.timings.duration < 300,
    'get cart total has valid response': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.user_id === userId && typeof body.total === 'number';
      } catch (e) {
        return false;
      }
    },
  });
  
  cartResponseTime.add(getCartTotalResponse.timings.duration);
  
  if (getCartTotalResponse.status === 200) {
    successfulRequests.add(1);
  } else {
    failedRequests.add(1);
    errorRate.add(1);
  }
  
  randomDelay();
  
  // Test 8: Clear cart (occasionally)
  if (Math.random() < 0.3) { // 30% chance to clear cart
    const clearCartResponse = http.del(`${cartServiceUrl}/${userId}/items`);
    
    check(clearCartResponse, {
      'clear cart status is 200': (r) => r.status === 200,
      'clear cart response time < 200ms': (r) => r.timings.duration < 200,
      'clear cart has valid response': (r) => {
        try {
          const body = JSON.parse(r.body);
          return body.user_id === userId;
        } catch (e) {
          return false;
        }
      },
    });
    
    clearCartTime.add(clearCartResponse.timings.duration);
    
    if (clearCartResponse.status === 200) {
      successfulRequests.add(1);
    } else {
      failedRequests.add(1);
      errorRate.add(1);
    }
    
    randomDelay();
  }
}

// Setup function (runs once before the test)
export function setup() {
  console.log('Starting Cart Service Performance Test');
  console.log(`Base URL: ${__ENV.BASE_URL || 'http://localhost:8080'}`);
  console.log('Test will run for 16 minutes with varying load');
  console.log('Testing cart operations: add, get, update, remove, clear');
}

// Teardown function (runs once after the test)
export function teardown(data) {
  console.log('Cart Service Performance Test completed');
  console.log('Check the results for performance insights');
} 