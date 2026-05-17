const bcrypt = require('bcryptjs');
const { PrismaClient } = require('@prisma/client');
require('dotenv').config();

const prisma = new PrismaClient();

const venueImages = [
  'https://images.unsplash.com/photo-1519167758481-83f29c8f8c17?auto=format&fit=crop&w=1200&q=80',
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
  'https://images.unsplash.com/photo-1566737236500-c8ac43014a8e?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1503428593586-e225b39bddfe?auto=format&fit=crop&w=1200&q=80'
];

const bookingAmounts = (price) => ({
  totalAmount: price,
  depositAmount: price * 0.5,
  remainingBalance: price * 0.5,
  serviceFee: price * 0.1
});

const temporaryVenues = [
  {
    name: 'Tacloban Bayfront Events Hall',
    description: 'A clean seaside-inspired hall for birthdays, seminars, receptions, and community celebrations near downtown Tacloban.',
    pricePerDay: 42000,
    capacity: 160,
    location: 'Tacloban City, Leyte',
    address: 'Magsaysay Boulevard, Tacloban City, Leyte',
    status: 'APPROVED',
    imageIndexes: [0, 2],
    amenities: ['Air conditioning', 'Parking', 'Catering partner', 'Wi-Fi'],
    facilities: ['Main event hall', 'Stage area', 'Sound system', 'Prep room']
  },
  {
    name: 'Palo Heritage Garden Venue',
    description: 'An outdoor garden-style venue for weddings, debuts, and family milestones in Palo.',
    pricePerDay: 38000,
    capacity: 120,
    location: 'Palo, Leyte',
    address: 'Palo Town Center, Palo, Leyte',
    status: 'APPROVED',
    imageIndexes: [1, 5],
    amenities: ['Garden setup', 'Parking', 'Basic lights', 'Photo area'],
    facilities: ['Garden lawn', 'Covered dining area', 'Bridal room', 'Pantry']
  },
  {
    name: 'Ormoc Grand Social Hall',
    description: 'A polished indoor venue for corporate gatherings, reunions, and formal family events.',
    pricePerDay: 46000,
    capacity: 190,
    location: 'Ormoc City, Leyte',
    address: 'Aviles Street, Ormoc City, Leyte',
    status: 'APPROVED',
    imageIndexes: [3, 6],
    amenities: ['Air conditioning', 'LED wall', 'Catering partner', 'Security'],
    facilities: ['Grand ballroom', 'Lobby', 'VIP room', 'Audio booth']
  },
  {
    name: 'Baybay Hilltop Pavilion',
    description: 'A breezy pavilion suited for intimate weddings, retreats, and private dinners in Baybay.',
    pricePerDay: 35000,
    capacity: 95,
    location: 'Baybay City, Leyte',
    address: 'Diversion Road, Baybay City, Leyte',
    status: 'APPROVED',
    imageIndexes: [4, 7],
    amenities: ['Scenic view', 'Parking', 'Outdoor lights', 'Backup generator'],
    facilities: ['Open pavilion', 'Dining deck', 'Kitchen area', 'Changing room']
  },
  {
    name: 'Guiuan Coastal Function House',
    description: 'A relaxed coastal venue for beach-themed birthdays, small receptions, and weekend celebrations.',
    pricePerDay: 30000,
    capacity: 80,
    location: 'Guiuan, Eastern Samar',
    address: 'Poblacion, Guiuan, Eastern Samar',
    status: 'APPROVED',
    imageIndexes: [2, 4],
    amenities: ['Coastal view', 'Basic sound', 'Parking', 'E-wallet accepted'],
    facilities: ['Function room', 'Outdoor dining space', 'Prep area', 'Storage room']
  },
  {
    name: 'Catbalogan City Events Loft',
    description: 'A compact modern loft for meetings, birthdays, showers, and small social events.',
    pricePerDay: 28000,
    capacity: 70,
    location: 'Catbalogan City, Samar',
    address: 'Downtown Catbalogan City, Samar',
    status: 'APPROVED',
    imageIndexes: [5, 0],
    amenities: ['Wi-Fi', 'Air conditioning', 'Projector', 'Coffee station'],
    facilities: ['Event loft', 'Meeting corner', 'Pantry', 'Reception desk']
  },
  {
    name: 'Maasin Seaview Convention Hall',
    description: 'A seaside function hall for school banquets, anniversaries, and civic events in Southern Leyte.',
    pricePerDay: 34000,
    capacity: 130,
    location: 'Maasin City, Southern Leyte',
    address: 'Tunga-tunga Road, Maasin City, Southern Leyte',
    status: 'APPROVED',
    imageIndexes: [8, 2],
    amenities: ['Sea view', 'Air conditioning', 'Parking', 'Basic sound'],
    facilities: ['Convention hall', 'Lobby', 'Dining area', 'Prep room']
  },
  {
    name: 'Calbayog Grand Function Center',
    description: 'A spacious Samar venue for graduation parties, seminars, and large family gatherings.',
    pricePerDay: 40000,
    capacity: 180,
    location: 'Calbayog City, Samar',
    address: 'Maharlika Highway, Calbayog City, Samar',
    status: 'APPROVED',
    imageIndexes: [9, 3],
    amenities: ['Air conditioning', 'Parking', 'Projector', 'Security desk'],
    facilities: ['Grand hall', 'Breakout room', 'Reception lobby', 'Kitchen area']
  },
  {
    name: 'Naval Island View Event Deck',
    description: 'A Biliran-inspired deck venue for intimate receptions, birthdays, and sunset dinners.',
    pricePerDay: 31000,
    capacity: 85,
    location: 'Naval, Biliran',
    address: 'Cathedral Road, Naval, Biliran',
    status: 'APPROVED',
    imageIndexes: [10, 4],
    amenities: ['Outdoor lights', 'Island view', 'Parking', 'E-wallet accepted'],
    facilities: ['Event deck', 'Covered dining', 'Preparation room', 'Storage']
  },
  {
    name: 'Tanauan Family Celebration Hall',
    description: 'A practical Leyte town venue for birthdays, reunions, christenings, and school activities.',
    pricePerDay: 26000,
    capacity: 90,
    location: 'Tanauan, Leyte',
    address: 'Real Street, Tanauan, Leyte',
    status: 'APPROVED',
    imageIndexes: [11, 1],
    amenities: ['Tables and chairs', 'Basic sound', 'Parking', 'Stage lights'],
    facilities: ['Celebration hall', 'Stage', 'Serving area', 'Changing room']
  },
  {
    name: 'Dulag Coastal Pavilion',
    description: 'An open-air pavilion for community programs, small weddings, and beach-themed events.',
    pricePerDay: 24000,
    capacity: 75,
    location: 'Dulag, Leyte',
    address: 'Coastal Road, Dulag, Leyte',
    status: 'APPROVED',
    imageIndexes: [12, 7],
    amenities: ['Open-air setup', 'Coastal breeze', 'Parking', 'Basic lights'],
    facilities: ['Pavilion', 'Outdoor dining area', 'Kitchenette', 'Storage room']
  },
  {
    name: 'Sogod Academic Events Hall',
    description: 'A Southern Leyte demo venue for school symposiums, trainings, and recognition ceremonies.',
    pricePerDay: 29000,
    capacity: 110,
    location: 'Sogod, Southern Leyte',
    address: 'Osmena Street, Sogod, Southern Leyte',
    status: 'APPROVED',
    imageIndexes: [13, 0],
    amenities: ['Projector', 'Wi-Fi', 'Air conditioning', 'Podium'],
    facilities: ['Academic hall', 'Meeting room', 'Registration desk', 'Pantry']
  },
  {
    name: 'Borongan Riverside Hall',
    description: 'A pending listing for admin review demos in Eastern Samar.',
    pricePerDay: 32000,
    capacity: 100,
    location: 'Borongan City, Eastern Samar',
    address: 'Riverside Road, Borongan City, Eastern Samar',
    status: 'PENDING',
    imageIndexes: [6],
    amenities: ['Parking', 'Basic lights', 'Tables and chairs'],
    facilities: ['Main hall', 'Kitchenette']
  }
];

const createVenue = (hostId, venue) =>
  prisma.venue.create({
    data: {
      hostId,
      name: venue.name,
      description: venue.description,
      pricePerDay: venue.pricePerDay,
      capacity: venue.capacity,
      location: venue.location,
      address: venue.address,
      status: venue.status,
      images: {
        create: venue.imageIndexes.map((imageIndex, sortOrder) => ({
          imageUrl: venueImages[imageIndex],
          sortOrder
        }))
      },
      amenities: { create: venue.amenities.map((name) => ({ name })) },
      facilities: { create: venue.facilities.map((name) => ({ name })) }
    }
  });

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
