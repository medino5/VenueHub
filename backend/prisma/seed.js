const bcrypt = require('bcryptjs');
const { PrismaClient } = require('@prisma/client');
require('dotenv').config();

const prisma = new PrismaClient();

const venueImages = [
  'https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1464366400600-7168b8af9bc3?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1511795409834-ef04bbd61622?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1505236858219-8359eb29e329?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1527529482837-4698179dc6ce?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1519225421980-715cb0215aed?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1507504031003-b417219a0fde?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1519741497674-611481863552?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1511578314322-379afb476865?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1469371670807-013ccf25f16a?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1517457373958-b7bdd4587205?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1503428593586-e225b39bddfe?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1505373877841-8d25f7d46678?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1521737604893-d14cc237f11d?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1527529482837-4698179dc6ce?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?auto=format&fit=crop&w=1200&q=80'
];

const realVenueImages = {
  taclobanConventionCenter: [
    'https://upload.wikimedia.org/wikipedia/en/thumb/b/b4/Tacloban_City_Convention_Center_front_%28Real_Street%2C_Tacloban%2C_Leyte%3B_09-08-2022%29.jpg/1280px-Tacloban_City_Convention_Center_front_%28Real_Street%2C_Tacloban%2C_Leyte%3B_09-08-2022%29.jpg'
  ],
  theTropics: [
    'https://ak-d.tripcdn.com/images/1z61q12000nusfuy2BBD9.jpg',
    'https://ak-d.tripcdn.com/images/1re3i12000ec1uteo4BA1.webp'
  ],
  playaAlegre: [
    'https://playa-alegre-beach-resort-restaurant.visayas-hotels.com/data/Pics/700x500w/13462/1346254/1346254370/playa-alegre-beach-resort-restaurant-tanauan-leyte-pic-1.JPEG',
    'https://playa-alegre-beach-resort-restaurant.visayas-hotels.com/data/Pics/700x500w/17320/1732049/1732049142/playa-alegre-beach-resort-restaurant-tanauan-leyte-pic-2.JPEG'
  ],
  summitTacloban: [
    'https://ak-d.tripcdn.com/images/0220j12000o1lro7p01DB.jpg',
    'https://ak-d.tripcdn.com/images/1mc5y12000o0x3vbhD168_R_500_400_R5.webp'
  ],
  pacificPoint: [
    'https://img.restaurantguru.com/w550/h367/rb40-Pacific-Point-Events-Place-and-Resort-Inc-facade-2022-09-2.jpg',
    'https://img02.restaurantguru.com/c5b2-Restaurant-Pacific-Point-Events-Place-and-Resort-Inc-exterior.jpg'
  ]
};

const venueCoordinates = {
  'Leyte Convention Complex': [11.159448, 124.990814],
  'The Tropics at MacArthur Park Resort and Convention Center': [11.163523, 125.004271],
  'Arcivu Hall': [11.159655, 124.992231],
  'Playa Alegre': [11.112276, 125.021208],
  'Banez Catering Services': [11.111211, 125.016919],
  'Haiyan Hotel and Resort': [11.1104, 125.0181],
  "ShyDan's Beach Center": [10.953244, 125.033452],
  'Camp Bryztoff': [10.9519, 125.0337],
  'Dulag Cultural Center': [10.953529, 125.034146],
  'Tacloban City Convention Center': [11.2444, 125.0005],
  'The Pavilion': [11.2419, 125.0038],
  "Sophia's Way Event Center": [11.222857, 125.001154],
  'Antonios Event Center': [11.20383, 125.020509],
  'Cancabato Bay Sunset': [11.214509, 125.023794],
  'Ritz Tower de Leyte': [11.244093, 125.001422],
  "Myco's Place Tacloban": [11.201936, 125.006776],
  'Summit Hotel Tacloban Ballroom and Meeting Suites': [11.208056, 125.007281],
  'Le Jardin de Tacloban': [11.2289, 125.0058],
  'Pacific Point Events Place and Resort Inc.': [11.1967, 125.0209],
  "Palm's Jewel Resort": [11.189519, 124.783188],
  "Sheila's Villa": [11.1876, 124.7842],
  'Villaconzoilo Compact Organic Farm': [11.2036, 124.8359],
  'Origami Convention Center': [11.009035, 124.609394],
  'ZT Leisure Park': [11.0316, 124.6087],
  'ROSETTA Guest House': [11.0068, 124.6071],
  'Camp Kawayan Resort': [10.978997, 124.910294],
  "Teresita's Garden": [10.986909, 124.891691],
  'Garden Paradise By The Lake Farm Resort': [10.974871, 124.893223],
  'Burauen Community Center': [10.974377, 124.891765],
  'Calbayog Cultural Convention Center': [12.066963, 124.594666],
  'M Grand Royale Resort, Hotel and Convention Center': [11.775053, 124.883907],
  'SSU Convention Center': [11.771232, 124.885358],
  'Ibabao Hall, Capitol Building': [12.504133, 124.632916]
};

const bookingAmounts = (price) => ({
  totalAmount: price,
  depositAmount: price * 0.5,
  remainingBalance: price * 0.5,
  serviceFee: price * 0.1
});

const unique = (items) => [...new Set(items.filter(Boolean))];

const eventVenue = ({
  name,
  city,
  province,
  address,
  capacity,
  pricePerDay,
  description,
  status = 'APPROVED',
  imageIndexes,
  imageUrls = [],
  amenities = [],
  facilities = []
}) => ({
  name,
  description,
  pricePerDay,
  capacity,
  location: `${city}, ${province}`,
  address,
  status,
  imageIndexes,
  imageUrls,
  amenities: unique(['Parking', 'Basic lights', ...amenities]),
  facilities: unique(['Tables and chairs', ...facilities])
});

const temporaryVenues = [
  eventVenue({
    name: 'Leyte Convention Complex',
    city: 'Palo',
    province: 'Leyte',
    address: 'Palo, Leyte, Philippines',
    capacity: 3100,
    pricePerDay: 150000,
    description: 'Large convention venue suitable for conferences, graduations, concerts, expos, and formal events.',
    imageIndexes: [14, 0],
    amenities: ['Air conditioning', 'Wi-Fi', 'Security assistance'],
    facilities: ['Convention hall', 'Stage area', 'Registration lobby', 'Breakout rooms']
  }),
  eventVenue({
    name: 'The Tropics at MacArthur Park Resort and Convention Center',
    city: 'Palo',
    province: 'Leyte',
    address: 'Barangay Baras, Palo, Leyte, Philippines',
    capacity: 500,
    pricePerDay: 120000,
    description: 'Resort and convention venue suitable for weddings, meetings, corporate events, and private gatherings.',
    imageUrls: realVenueImages.theTropics,
    imageIndexes: [9, 2],
    amenities: ['Air conditioning', 'Catering partner', 'Garden setup', 'Photo area'],
    facilities: ['Ballroom', 'Garden lawn', 'Poolside area', 'Meeting suites']
  }),
  eventVenue({
    name: 'Arcivu Hall',
    city: 'Palo',
    province: 'Leyte',
    address: 'Palo, Leyte, Philippines',
    capacity: 150,
    pricePerDay: 26000,
    description: 'Function hall venue for private gatherings, receptions, meetings, and community events.',
    imageIndexes: [2, 15],
    amenities: ['Air conditioning', 'Catering partner'],
    facilities: ['Function hall', 'Serving area', 'Prep room']
  }),
  eventVenue({
    name: 'Playa Alegre',
    city: 'Tanauan',
    province: 'Leyte',
    address: 'Tanauan, Leyte, Philippines',
    capacity: 120,
    pricePerDay: 25000,
    description: 'Beach-style venue suitable for outings, celebrations, receptions, and private events.',
    imageUrls: realVenueImages.playaAlegre,
    imageIndexes: [4, 7],
    amenities: ['Photo area', 'Outdoor setup', 'Coastal view'],
    facilities: ['Beachfront area', 'Covered dining area', 'Changing room']
  }),
  eventVenue({
    name: 'Banez Catering Services',
    city: 'Tanauan',
    province: 'Leyte',
    address: 'Tanauan, Leyte, Philippines',
    capacity: 150,
    pricePerDay: 35000,
    description: 'Catering and event service provider for birthdays, weddings, receptions, and local celebrations.',
    imageIndexes: [2, 11],
    amenities: ['Catering partner', 'Event styling', 'Food service'],
    facilities: ['Mobile buffet setup', 'Event coordination desk', 'Serving area']
  }),
  eventVenue({
    name: 'Haiyan Hotel and Resort',
    city: 'Tanauan',
    province: 'Leyte',
    address: 'Tanauan, Leyte, Philippines',
    capacity: 160,
    pricePerDay: 42000,
    description: 'Hotel and resort venue suitable for accommodations, private events, meetings, and celebrations.',
    imageIndexes: [9, 16],
    amenities: ['Air conditioning', 'Catering partner', 'Pool access'],
    facilities: ['Function room', 'Resort dining area', 'Guest rooms']
  }),
  eventVenue({
    name: "ShyDan's Beach Center",
    city: 'Dulag',
    province: 'Leyte',
    address: 'Dulag, Leyte, Philippines',
    capacity: 120,
    pricePerDay: 18000,
    description: 'Beach center venue suitable for outings, reunions, casual events, and private celebrations.',
    imageIndexes: [4, 12],
    amenities: ['Outdoor setup', 'Coastal view', 'Basic sound'],
    facilities: ['Beach center', 'Open dining area', 'Changing room']
  }),
  eventVenue({
    name: 'Camp Bryztoff',
    city: 'Dulag',
    province: 'Leyte',
    address: 'Dulag, Leyte, Philippines',
    capacity: 150,
    pricePerDay: 22000,
    description: 'Outdoor venue suitable for camping activities, retreats, team buildings, and private gatherings.',
    imageIndexes: [6, 13],
    amenities: ['Outdoor setup', 'Security assistance', 'Photo area'],
    facilities: ['Camp grounds', 'Activity field', 'Covered pavilion']
  }),
  eventVenue({
    name: 'Dulag Cultural Center',
    city: 'Dulag',
    province: 'Leyte',
    address: 'Dulag, Leyte, Philippines',
    capacity: 600,
    pricePerDay: 30000,
    description: 'Cultural and community venue suitable for programs, seminars, ceremonies, and local government events.',
    imageIndexes: [14, 10],
    amenities: ['Air conditioning', 'Projector', 'Sound system'],
    facilities: ['Cultural hall', 'Stage area', 'Backstage room']
  }),
  eventVenue({
    name: 'Tacloban City Convention Center',
    city: 'Tacloban City',
    province: 'Leyte',
    address: 'Esperas Avenue, Tacloban City, Leyte, Philippines',
    capacity: 5000,
    pricePerDay: 180000,
    description: 'One of the biggest venues in Eastern Visayas, suitable for conventions, concerts, graduations, expos, and corporate events.',
    imageUrls: realVenueImages.taclobanConventionCenter,
    imageIndexes: [14, 0],
    amenities: ['Air conditioning', 'Security assistance', 'Sound system'],
    facilities: ['Convention arena', 'Stage area', 'Exhibit floor', 'Registration lobby']
  }),
  eventVenue({
    name: 'The Pavilion',
    city: 'Tacloban City',
    province: 'Leyte',
    address: 'Tacloban City, Leyte, Philippines',
    capacity: 300,
    pricePerDay: 65000,
    description: 'Elegant indoor venue commonly used for weddings, debuts, seminars, and receptions.',
    imageIndexes: [2, 5],
    amenities: ['Air conditioning', 'Catering partner', 'Photo area'],
    facilities: ['Function hall', 'Bridal room', 'Reception lobby']
  }),
  eventVenue({
    name: "Sophia's Way Event Center",
    city: 'Tacloban City',
    province: 'Leyte',
    address: 'Sagkahan, Tacloban City, Leyte, Philippines',
    capacity: 150,
    pricePerDay: 30000,
    description: 'Event venue suitable for birthdays, intimate receptions, family gatherings, and private celebrations.',
    imageIndexes: [1, 2],
    amenities: ['Air conditioning', 'Catering partner', 'Photo area'],
    facilities: ['Event center', 'Prep room', 'Serving area']
  }),
  eventVenue({
    name: 'Antonios Event Center',
    city: 'Tacloban City',
    province: 'Leyte',
    address: 'San Jose, Tacloban City, Leyte, Philippines',
    capacity: 250,
    pricePerDay: 45000,
    description: 'Private event venue for weddings, birthdays, corporate events, and customizable reception layouts.',
    imageIndexes: [2, 10],
    amenities: ['Air conditioning', 'Sound system', 'Catering partner'],
    facilities: ['Event hall', 'Stage area', 'Changing room']
  }),
  eventVenue({
    name: 'Cancabato Bay Sunset',
    city: 'Tacloban City',
    province: 'Leyte',
    address: 'Tacloban City, Leyte, Philippines',
    capacity: 200,
    pricePerDay: 36000,
    description: 'Bay-view venue popular for sunset receptions, prenup shoots, private parties, and scenic events.',
    imageIndexes: [4, 8],
    amenities: ['Photo area', 'Outdoor setup', 'Bay view'],
    facilities: ['Bay-view deck', 'Covered dining area', 'Prep area']
  }),
  eventVenue({
    name: 'Ritz Tower de Leyte',
    city: 'Tacloban City',
    province: 'Leyte',
    address: 'Downtown Tacloban City, Leyte, Philippines',
    capacity: 400,
    pricePerDay: 70000,
    description: 'Downtown venue used for formal gatherings, weddings, receptions, and social events.',
    imageIndexes: [9, 2],
    amenities: ['Air conditioning', 'Catering partner', 'Security assistance'],
    facilities: ['Reception hall', 'Lobby', 'Meeting suites']
  }),
  eventVenue({
    name: "Myco's Place Tacloban",
    city: 'Tacloban City',
    province: 'Leyte',
    address: 'Marasbaras, Tacloban City, Leyte, Philippines',
    capacity: 120,
    pricePerDay: 20000,
    description: 'Small-to-medium private venue suitable for birthdays, meetings, and family events.',
    imageIndexes: [5, 15],
    amenities: ['Air conditioning', 'Catering partner'],
    facilities: ['Private hall', 'Dining area', 'Kitchenette']
  }),
  eventVenue({
    name: 'Summit Hotel Tacloban Ballroom and Meeting Suites',
    city: 'Tacloban City',
    province: 'Leyte',
    address: 'Beside Robinsons Tacloban, Tacloban City, Leyte, Philippines',
    capacity: 600,
    pricePerDay: 110000,
    description: 'Hotel ballroom and meeting suites suitable for conferences, trainings, seminars, weddings, and receptions.',
    imageUrls: realVenueImages.summitTacloban,
    imageIndexes: [9, 0],
    amenities: ['Air conditioning', 'Wi-Fi', 'Catering partner', 'Projector'],
    facilities: ['Grand ballroom', 'Meeting suites', 'Pre-function lobby']
  }),
  eventVenue({
    name: 'Le Jardin de Tacloban',
    city: 'Tacloban City',
    province: 'Leyte',
    address: 'Tacloban City, Leyte, Philippines',
    capacity: 200,
    pricePerDay: 45000,
    description: 'Garden-style venue for outdoor events, receptions, parties, and social gatherings.',
    imageIndexes: [1, 6],
    amenities: ['Garden setup', 'Photo area', 'Outdoor setup'],
    facilities: ['Garden lawn', 'Covered dining area', 'Bridal room']
  }),
  eventVenue({
    name: 'Pacific Point Events Place and Resort Inc.',
    city: 'Tacloban City',
    province: 'Leyte',
    address: 'Tacloban City, Leyte, Philippines',
    capacity: 300,
    pricePerDay: 38000,
    description: 'Oceanfront resort and events venue with pools, dining areas, and event facilities.',
    imageUrls: realVenueImages.pacificPoint,
    imageIndexes: [4, 9],
    amenities: ['Pool access', 'Catering partner', 'Photo area', 'Outdoor setup'],
    facilities: ['Poolside venue', 'Dining pavilion', 'Resort grounds']
  }),
  eventVenue({
    name: "Palm's Jewel Resort",
    city: 'Jaro',
    province: 'Leyte',
    address: 'Jaro, Leyte, Philippines',
    capacity: 200,
    pricePerDay: 32000,
    description: 'Resort venue suitable for outings, reunions, overnight stays, and family gatherings.',
    imageIndexes: [9, 4],
    amenities: ['Pool access', 'Outdoor setup', 'Photo area'],
    facilities: ['Resort pavilion', 'Poolside area', 'Guest rooms']
  }),
  eventVenue({
    name: "Sheila's Villa",
    city: 'Jaro',
    province: 'Leyte',
    address: 'Jaro, Leyte, Philippines',
    capacity: 50,
    pricePerDay: 15000,
    description: 'Private villa venue for intimate celebrations, barkada outings, and small gatherings.',
    imageIndexes: [16, 6],
    amenities: ['Photo area', 'Outdoor setup'],
    facilities: ['Private villa', 'Dining patio', 'Kitchen area']
  }),
  eventVenue({
    name: 'Villaconzoilo Compact Organic Farm',
    city: 'Jaro',
    province: 'Leyte',
    address: 'Villaconzoilo, Jaro, Leyte, Philippines',
    capacity: 150,
    pricePerDay: 25000,
    description: 'Farm venue suitable for retreats, outdoor activities, eco-events, and nature-themed gatherings.',
    imageIndexes: [6, 13],
    amenities: ['Garden setup', 'Outdoor setup', 'Photo area'],
    facilities: ['Farm grounds', 'Covered pavilion', 'Activity field']
  }),
  eventVenue({
    name: 'Origami Convention Center',
    city: 'Ormoc City',
    province: 'Leyte',
    address: 'Ormoc City, Leyte, Philippines',
    capacity: 350,
    pricePerDay: 55000,
    description: 'Air-conditioned convention hall used for weddings, seminars, conferences, and receptions.',
    imageIndexes: [0, 14],
    amenities: ['Air conditioning', 'Wi-Fi', 'Projector', 'Sound system'],
    facilities: ['Convention hall', 'Stage area', 'Registration lobby']
  }),
  eventVenue({
    name: 'ZT Leisure Park',
    city: 'Ormoc City',
    province: 'Leyte',
    address: 'Palompon Highway, Ormoc City, Leyte, Philippines',
    capacity: 250,
    pricePerDay: 30000,
    description: 'Leisure park suitable for private functions, outdoor events, and recreational activities.',
    imageIndexes: [6, 4],
    amenities: ['Outdoor setup', 'Photo area', 'Garden setup'],
    facilities: ['Leisure park grounds', 'Covered area', 'Activity lawn']
  }),
  eventVenue({
    name: 'ROSETTA Guest House',
    city: 'Ormoc City',
    province: 'Leyte',
    address: 'Near Rizal Street, Ormoc City, Leyte, Philippines',
    capacity: 120,
    pricePerDay: 28000,
    description: 'Guest house and function venue suitable for meetings, small receptions, and overnight stays.',
    imageIndexes: [9, 5],
    amenities: ['Air conditioning', 'Wi-Fi', 'Catering partner'],
    facilities: ['Function room', 'Guest rooms', 'Dining area']
  }),
  eventVenue({
    name: 'Camp Kawayan Resort',
    city: 'Burauen',
    province: 'Leyte',
    address: 'Burauen, Leyte, Philippines',
    capacity: 250,
    pricePerDay: 30000,
    description: 'Nature-inspired resort venue popular for retreats, team buildings, and outdoor events.',
    imageIndexes: [6, 13],
    amenities: ['Outdoor setup', 'Photo area', 'Security assistance'],
    facilities: ['Resort grounds', 'Activity area', 'Covered pavilion']
  }),
  eventVenue({
    name: "Teresita's Garden",
    city: 'Burauen',
    province: 'Leyte',
    address: 'Maghubas, Burauen, Leyte, Philippines',
    capacity: 150,
    pricePerDay: 28000,
    description: 'Open-air garden venue suitable for receptions, prenup shoots, and intimate celebrations.',
    imageIndexes: [1, 6],
    amenities: ['Garden setup', 'Photo area', 'Outdoor setup'],
    facilities: ['Garden venue', 'Covered dining area', 'Prep room']
  }),
  eventVenue({
    name: 'Garden Paradise By The Lake Farm Resort',
    city: 'Burauen',
    province: 'Leyte',
    address: 'Burauen, Leyte, Philippines',
    capacity: 200,
    pricePerDay: 35000,
    description: 'Farm resort venue with scenic lake surroundings for retreats, family gatherings, and private events.',
    imageIndexes: [6, 4],
    amenities: ['Garden setup', 'Photo area', 'Lake view'],
    facilities: ['Farm resort grounds', 'Lakefront area', 'Dining pavilion']
  }),
  eventVenue({
    name: 'Burauen Community Center',
    city: 'Burauen',
    province: 'Leyte',
    address: 'Burauen, Leyte, Philippines',
    capacity: 1500,
    pricePerDay: 40000,
    description: 'Community venue used for municipal programs, public functions, and large local events.',
    imageIndexes: [14, 10],
    amenities: ['Sound system', 'Security assistance'],
    facilities: ['Community hall', 'Stage area', 'Backstage room']
  }),
  eventVenue({
    name: 'Calbayog Cultural Convention Center',
    city: 'Calbayog City',
    province: 'Samar',
    address: 'Calbayog City, Samar, 6710 Philippines',
    capacity: 500,
    pricePerDay: 60000,
    description: 'Cultural and convention venue suitable for large events, programs, seminars, and public gatherings.',
    imageIndexes: [14, 0],
    amenities: ['Air conditioning', 'Sound system', 'Projector'],
    facilities: ['Cultural hall', 'Convention floor', 'Stage area']
  }),
  eventVenue({
    name: 'M Grand Royale Resort, Hotel and Convention Center',
    city: 'Catbalogan City',
    province: 'Samar',
    address: 'Brgy. Guinsorongan, Catbalogan City, Samar, Philippines',
    capacity: 350,
    pricePerDay: 75000,
    description: 'Resort, hotel, and convention venue with conference facilities, accommodations, and event spaces.',
    imageIndexes: [9, 0],
    amenities: ['Air conditioning', 'Wi-Fi', 'Catering partner', 'Pool access'],
    facilities: ['Convention center', 'Hotel rooms', 'Resort dining area']
  }),
  eventVenue({
    name: 'SSU Convention Center',
    city: 'Catbalogan City',
    province: 'Samar',
    address: 'QVCP+F4H, Arteche Blvd, Catbalogan City Proper, Catbalogan City, Samar, Philippines',
    capacity: 500,
    pricePerDay: 45000,
    description: 'Convention center venue suitable for academic events, seminars, conferences, and institutional programs.',
    imageIndexes: [14, 15],
    amenities: ['Air conditioning', 'Projector', 'Sound system'],
    facilities: ['Academic convention hall', 'Stage area', 'Registration desk']
  }),
  eventVenue({
    name: 'Ibabao Hall, Capitol Building',
    city: 'Catarman',
    province: 'Northern Samar',
    address: 'Capitol Building, Catarman, Northern Samar, Philippines',
    capacity: 250,
    pricePerDay: 25000,
    description: 'Government function hall suitable for official programs, meetings, ceremonies, and public events.',
    imageIndexes: [15, 10],
    amenities: ['Air conditioning', 'Projector', 'Sound system'],
    facilities: ['Government function hall', 'Meeting area', 'Program stage']
  })
];

const createVenue = (hostId, venue) => {
  const imageUrls = unique([
    ...(venue.imageUrls || []),
    ...(venue.imageIndexes || []).map((imageIndex) => venueImages[imageIndex])
  ]);
  const [latitude, longitude] = venueCoordinates[venue.name] || [];

  return prisma.venue.create({
    data: {
      hostId,
      name: venue.name,
      description: venue.description,
      pricePerDay: venue.pricePerDay,
      capacity: venue.capacity,
      location: venue.location,
      address: venue.address,
      latitude,
      longitude,
      status: venue.status,
      images: {
        create: imageUrls.map((imageUrl, sortOrder) => ({
          imageUrl,
          sortOrder
        }))
      },
      amenities: { create: venue.amenities.map((name) => ({ name })) },
      facilities: { create: venue.facilities.map((name) => ({ name })) }
    }
  });
};

async function main() {
  await prisma.review.deleteMany();
  await prisma.receipt.deleteMany();
  await prisma.payment.deleteMany();
  await prisma.booking.deleteMany();
  await prisma.notification.deleteMany();
  await prisma.facility.deleteMany();
  await prisma.amenity.deleteMany();
  await prisma.venueImage.deleteMany();
  await prisma.venue.deleteMany();
  await prisma.user.deleteMany();

  const password = await bcrypt.hash('password123', 12);

  const [customer, host, admin] = await Promise.all([
    prisma.user.create({
      data: {
        name: 'Carla Demo',
        email: 'customer@venuehub.test',
        password,
        role: 'CUSTOMER',
        gender: 'Female',
        phone: '+63 917 000 1000',
        preferences: 'Indoor venues with parking and simple blue-white styling.',
        likes: 'Garden receptions, clean halls, responsive hosts',
        dislikes: 'Hidden fees, poor parking, unclear cancellation terms',
        specialNotes: 'Usually books for family milestones and school events.',
        profileImageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=400&q=80'
      }
    }),
    prisma.user.create({
      data: {
        name: 'Marco Host',
        email: 'host@venuehub.test',
        password,
        role: 'HOST',
        gender: 'Male',
        phone: '+63 917 000 2000',
        preferences: 'Prefers complete event details before approving requests.',
        likes: 'Organized customers, clear headcount, early deposit payment',
        dislikes: 'Last-minute changes',
        specialNotes: 'Demo host account for Eastern Visayas venues.',
        profileImageUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80'
      }
    }),
    prisma.user.create({
      data: {
        name: 'VenueHub Admin',
        email: 'admin@venuehub.test',
        password,
        role: 'VENUEHUB_ADMIN',
        phone: '+63 917 000 3000'
      }
    })
  ]);

  const venues = await Promise.all(temporaryVenues.map((venue) => createVenue(host.id, venue)));

  const amounts = bookingAmounts(temporaryVenues[0].pricePerDay);
  const booking = await prisma.booking.create({
    data: {
      customerId: customer.id,
      venueId: venues[0].id,
      eventDate: new Date(Date.now() + 1000 * 60 * 60 * 24 * 21),
      notes: 'Demo booking for an Eastern Visayas wedding reception.',
      status: 'APPROVED',
      paymentStatus: 'PARTIALLY_PAID',
      ...amounts
    }
  });

  await prisma.payment.create({
    data: {
      bookingId: booking.id,
      amount: amounts.depositAmount,
      method: 'GCASH',
      type: 'DEPOSIT',
      transactionRef: 'SIM-SEED-DEPOSIT-001'
    }
  });

  await prisma.receipt.create({
    data: {
      bookingId: booking.id,
      receiptNumber: 'VH-SEED-0001',
      subtotal: amounts.totalAmount,
      depositPaid: amounts.depositAmount,
      remainingBalance: amounts.remainingBalance,
      serviceFee: amounts.serviceFee,
      totalPaid: amounts.depositAmount,
      paymentMethod: 'GCASH',
      securityNote: '50% security deposit is non-refundable. Remaining balance is due before or on event day.'
    }
  });

  await prisma.platformSetting.upsert({
    where: { id: 'platform' },
    update: { serviceFeePercent: 10 },
    create: { id: 'platform', serviceFeePercent: 10 }
  });

  await prisma.notification.createMany({
    data: [
      {
        userId: customer.id,
        title: 'Booking approved',
        message: `${temporaryVenues[0].name} is approved for your demo event.`,
        type: 'BOOKING_STATUS',
        metadata: { bookingId: booking.id, venueId: venues[0].id, status: 'APPROVED' }
      },
      {
        userId: customer.id,
        title: 'Payment recorded',
        message: 'Your demo GCash deposit was recorded successfully.',
        type: 'PAYMENT',
        metadata: { bookingId: booking.id }
      }
    ]
  });

  console.log('Seed complete. Temporary Eastern Visayas venues are ready.');
  console.table([
    { role: 'customer', email: customer.email, password: 'password123' },
    { role: 'host', email: host.email, password: 'password123' },
    { role: 'admin', email: admin.email, password: 'password123' }
  ]);
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
