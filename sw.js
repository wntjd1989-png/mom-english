/* 서비스 워커 — 한 번 열어두면 인터넷 없이도 앱이 돌아갑니다.
   앱 전체가 index.html 한 파일이라 캐시 전략도 단순합니다. */
var CACHE = 'mom-english-20260815-213941';
var ASSETS = [
  './',
  './index.html',
  './manifest.webmanifest',
  './icon-192.png',
  './icon-512.png',
  './icon-maskable-512.png',
  './apple-touch-icon.png'
];

self.addEventListener('install', function (e) {
  e.waitUntil(
    caches.open(CACHE)
      .then(function (c) { return c.addAll(ASSETS); })
      .then(function () { return self.skipWaiting(); })
  );
});

/* 단어 사진 목록 — 빌드할 때 채워집니다 */
var IMAGES = ['img/airport.jpg','img/apple.jpg','img/baby.jpg','img/bag.jpg','img/banana.jpg','img/bank.jpg','img/baseball.jpg','img/beach.jpg','img/bear.jpg','img/bed.jpg','img/bee.jpg','img/bike.jpg','img/bird.jpg','img/boy.jpg','img/bread.jpg','img/breakfast.jpg','img/bus.jpg','img/butter.jpg','img/butterfly.jpg','img/cake.jpg','img/camera.jpg','img/car.jpg','img/card.jpg','img/carrot.jpg','img/cat.jpg','img/chair.jpg','img/cheese.jpg','img/chef.jpg','img/chicken.jpg','img/church.jpg','img/city.jpg','img/clean.jpg','img/clock.jpg','img/cloud.jpg','img/coffee.jpg','img/computer.jpg','img/cook.jpg','img/cookie.jpg','img/corn.jpg','img/cow.jpg','img/dance.jpg','img/dinner.jpg','img/doctor.jpg','img/dog.jpg','img/door.jpg','img/duck.jpg','img/ear.jpg','img/egg.jpg','img/elephant.jpg','img/evening.jpg','img/exercise.jpg','img/eye.jpg','img/fall.jpg','img/farmer.jpg','img/flower.jpg','img/food.jpg','img/foot.jpg','img/frog.jpg','img/garden.jpg','img/gift.jpg','img/girl.jpg','img/golf.jpg','img/grandmother.jpg','img/grape.jpg','img/hand.jpg','img/hat.jpg','img/horse.jpg','img/hospital.jpg','img/hotel.jpg','img/house.jpg','img/icecream.jpg','img/juice.jpg','img/key.jpg','img/library.jpg','img/lion.jpg','img/luggage.jpg','img/man.jpg','img/map.jpg','img/market.jpg','img/meat.jpg','img/medicine.jpg','img/menu.jpg','img/milk.jpg','img/money.jpg','img/monkey.jpg','img/moon.jpg','img/morning.jpg','img/mountain.jpg','img/mouth.jpg','img/museum.jpg','img/newspaper.jpg','img/night.jpg','img/noodle.jpg','img/nurse.jpg','img/office.jpg','img/onion.jpg','img/orange.jpg','img/park.jpg','img/passport.jpg','img/pen.jpg','img/phone.jpg','img/photo.jpg','img/pig.jpg','img/pizza.jpg','img/plane.jpg','img/police.jpg','img/potato.jpg','img/rabbit.jpg','img/radio.jpg','img/rain.jpg','img/read.jpg','img/restaurant.jpg','img/rice.jpg','img/run.jpg','img/salad.jpg','img/sandwich.jpg','img/school.jpg','img/sheep.jpg','img/shirt.jpg','img/shoe.jpg','img/sing.jpg','img/sleep.jpg','img/snake.jpg','img/snow.jpg','img/soccer.jpg','img/soup.jpg','img/spring.jpg','img/star.jpg','img/station.jpg','img/store.jpg','img/strawberry.jpg','img/student.jpg','img/sugar.jpg','img/summer.jpg','img/sun.jpg','img/swim.jpg','img/table.jpg','img/tea.jpg','img/teacher.jpg','img/tennis.jpg','img/ticket.jpg','img/tiger.jpg','img/tomato.jpg','img/train.jpg','img/tree.jpg','img/tv.jpg','img/umbrella.jpg','img/walk.jpg','img/water.jpg','img/watermelon.jpg','img/window.jpg','img/winter.jpg','img/woman.jpg'];

/* 사진은 설치를 막지 않고 뒤에서 조용히 받아 둡니다.
   그래야 앱이 바로 열리고, 잠시 뒤에는 인터넷 없이도 사진이 보입니다.
   - 앱을 먼저 쓰실 수 있게 몇 초 뒤에 시작하고
   - 한 번에 3장씩만 받아 화면이 버벅이지 않게 합니다
   - 데이터 절약 모드에서는 아예 받지 않습니다 (요금 아끼려고) */
function warmImages() {
  try {
    if (self.navigator && self.navigator.connection && self.navigator.connection.saveData) return;
  } catch (e) { }

  setTimeout(function () {
    caches.open(CACHE).then(function (c) {
      var i = 0;
      function worker() {
        if (i >= IMAGES.length) return Promise.resolve();
        var url = IMAGES[i++];
        return c.match(url)
          .then(function (hit) { return hit ? null : c.add(url); })
          .catch(function () { })
          .then(worker);
      }
      return Promise.all([worker(), worker(), worker()]);
    }).catch(function () { });
  }, 4000);
}

self.addEventListener('activate', function (e) {
  // 새 버전이 설치되면 옛날 캐시는 지웁니다
  e.waitUntil(
    caches.keys()
      .then(function (keys) {
        return Promise.all(keys.map(function (k) {
          return k === CACHE ? null : caches.delete(k);
        }));
      })
      .then(function () { return self.clients.claim(); })
      .then(function () { warmImages(); })      // 기다리지 않고 시작만
  );
});

self.addEventListener('fetch', function (e) {
  var req = e.request;
  if (req.method !== 'GET') return;
  if (new URL(req.url).origin !== self.location.origin) return;

  // 페이지 이동은 항상 index.html 로 (오프라인에서도 열리게)
  if (req.mode === 'navigate') {
    e.respondWith(
      caches.match('./index.html').then(function (hit) {
        return hit || fetch(req).catch(function () { return caches.match('./index.html'); });
      })
    );
    return;
  }

  // 나머지는 캐시 우선, 없으면 받아와서 캐시에 넣기
  e.respondWith(
    caches.match(req).then(function (hit) {
      if (hit) return hit;
      return fetch(req).then(function (res) {
        if (res && res.status === 200 && res.type === 'basic') {
          var copy = res.clone();
          caches.open(CACHE).then(function (c) { c.put(req, copy); });
        }
        return res;
      });
    })
  );
});
