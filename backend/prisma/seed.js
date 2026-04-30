const bcrypt = require('bcryptjs');
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

const imageUrls = [
  'https://images.unsplash.com/photo-1519167758481-83f29c8f8c17?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1464366400600-7168b8af9bc3?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1511795409834-ef04bbd61622?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1505236858219-8359eb29e329?auto=format&fit=crop&w=1200&q=80'
];

const bookingAmounts = (price) => ({
  totalAmount: price,
  depositAmount: price * 0.5,
  remainingBalance: price * 0.5,
  serviceFee: price * 0.1
});

async function main() {
  await prisma.review.deleteMany();
  await prisma.receipt.deleteMany();
  await prisma.payment.deleteMany();
  await prisma.booking.deleteMany();
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

  const venues = await Promise.all([
    prisma.venue.create({
      data: {
        hostId: host.id,
        name: 'The Glass Garden Pavilion',
        description: 'A bright garden event venue with glass walls, floral styling, and an elegant reception hall.',
        pricePerDay: 85000,
        capacity: 180,
        location: 'Tagaytay',
        address: 'Aguinaldo Highway, Tagaytay City',
        status: 'APPROVED',
        images: { create: imageUrls.slice(0, 2).map((imageUrl, sortOrder) => ({ imageUrl, sortOrder })) },
        amenities: { create: ['Air conditioning', 'Parking', 'Catering partner', 'Bridal room'].map((name) => ({ name })) },
        facilities: { create: ['Garden ceremony area', 'Reception hall', 'Sound system', 'Prep suite'].map((name) => ({ name })) }
      }
    }),
    prisma.venue.create({
      data: {
        hostId: host.id,
        name: 'Harbor Lights Rooftop',
        description: 'A skyline rooftop venue made for birthdays, corporate cocktails, and intimate evening events.',
        pricePerDay: 62000,
        capacity: 120,
        location: 'Pasay',
        address: 'Seaside Boulevard, Pasay City',
        status: 'APPROVED',
        images: { create: imageUrls.slice(2, 4).map((imageUrl, sortOrder) => ({ imageUrl, sortOrder })) },
        amenities: { create: ['City view', 'Bar access', 'LED wall', 'Valet parking'].map((name) => ({ name })) },
        facilities: { create: ['Rooftop deck', 'Indoor lounge', 'DJ booth', 'VIP room'].map((name) => ({ name })) }
      }
    }),
    prisma.venue.create({
      data: {
        hostId: host.id,
        name: 'Casa Amara Events Hall',
        description: 'A pending listing for admin approval demos.',
        pricePerDay: 43000,
        capacity: 90,
        location: 'Quezon City',
        address: 'Scout Area, Quezon City',
        status: 'PENDING',
        images: { create: [{ imageUrl: imageUrls[1], sortOrder: 0 }] },
        amenities: { create: ['Wi-Fi', 'Basic lights'].map((name) => ({ name })) },
        facilities: { create: ['Main hall', 'Pantry'].map((name) => ({ name })) }
      }
    })
  ]);

  const amounts = bookingAmounts(85000);
  const booking = await prisma.booking.create({
    data: {
      customerId: customer.id,
      venueId: venues[0].id,
      eventDate: new Date(Date.now() + 1000 * 60 * 60 * 24 * 21),
      notes: 'Demo booking for a wedding reception.',
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

  console.log('Seed complete.');
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
