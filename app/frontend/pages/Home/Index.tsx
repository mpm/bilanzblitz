import { Head, Link } from '@inertiajs/react'
import { ArrowRight, CheckCircle2, BarChart3, FileText, Calendar, Shield } from 'lucide-react'
import { Button } from '@/components/ui/button'

export default function Home() {
  return (
    <div className="min-h-screen bg-background">
      <Head title="BilanzBlitz - German Accounting Perfected" />

      {/* Navigation */}
      <nav className="fixed top-0 w-full z-50 bg-background/80 backdrop-blur-md border-b border-border">
        <div className="max-w-7xl mx-auto px-6 lg:px-8 py-4">
          <div className="flex items-center justify-between">
            <div className="text-2xl font-bold tracking-tight" style={{ fontFamily: 'var(--font-display)' }}>
              Bilanz<span className="text-primary">Blitz</span>
            </div>
            <div className="flex items-center gap-4">
              <Link href="/users/sign_in">
                <Button variant="ghost" className="font-medium">
                  Sign In
                </Button>
              </Link>
              <Link href="/users/sign_up">
                <Button className="font-medium">
                  Get Started
                  <ArrowRight className="ml-2 h-4 w-4" />
                </Button>
              </Link>
            </div>
          </div>
        </div>
      </nav>

      {/* Hero Section - Diagonal Split Design */}
      <section className="relative pt-32 pb-24 overflow-hidden">
        {/* Geometric Background Elements */}
        <div className="absolute inset-0 -z-10">
          <div className="absolute top-0 right-0 w-[800px] h-[800px] bg-primary/5 rounded-full blur-3xl -translate-y-1/2 translate-x-1/2" />
          <div className="absolute bottom-0 left-0 w-[600px] h-[600px] bg-green-500/5 rounded-full blur-3xl translate-y-1/2 -translate-x-1/2" />

          {/* Diagonal Lines */}
          <svg className="absolute inset-0 w-full h-full opacity-[0.03]" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <pattern id="diagonals" x="0" y="0" width="100" height="100" patternUnits="userSpaceOnUse">
                <line x1="0" y1="0" x2="100" y2="100" stroke="currentColor" strokeWidth="1"/>
              </pattern>
            </defs>
            <rect width="100%" height="100%" fill="url(#diagonals)" />
          </svg>
        </div>

        <div className="max-w-7xl mx-auto px-6 lg:px-8">
          <div className="grid lg:grid-cols-2 gap-16 items-center">
            {/* Left Column */}
            <div
              className="space-y-8 animate-[slideInLeft_0.8s_ease-out]"
              style={{ fontFamily: 'var(--font-display)' }}
            >
              <div className="inline-block px-4 py-2 bg-primary/10 rounded-full">
                <span className="text-sm font-semibold text-primary tracking-wide uppercase">
                  Deutsche Präzision
                </span>
              </div>

              <h1 className="text-6xl lg:text-7xl xl:text-8xl font-extrabold leading-[0.95] tracking-tight">
                Accounting
                <br />
                <span className="text-primary">Simplified.</span>
                <br />
                <span className="text-foreground/40">Perfected.</span>
              </h1>

              <p
                className="text-xl text-muted-foreground leading-relaxed max-w-xl"
                style={{ fontFamily: 'var(--font-body)' }}
              >
                Professional bookkeeping for German GmbHs and UGs.
                Bank sync, VAT reports, and annual filings—all in one place.
                <span className="block mt-2 font-semibold text-foreground">
                  GoBD-compliant from day one.
                </span>
              </p>

              <div className="flex flex-wrap gap-4 pt-4">
                <Link href="/users/sign_up">
                  <Button size="lg" className="text-lg px-8 py-6 shadow-lg shadow-primary/20 hover:shadow-xl hover:shadow-primary/30 transition-all">
                    Start Free Trial
                    <ArrowRight className="ml-2 h-5 w-5" />
                  </Button>
                </Link>
                <Button size="lg" variant="outline" className="text-lg px-8 py-6">
                  Watch Demo
                </Button>
              </div>

              {/* Trust Indicators */}
              <div className="flex flex-wrap items-center gap-6 pt-8 text-sm text-muted-foreground">
                <div className="flex items-center gap-2">
                  <CheckCircle2 className="h-5 w-5 text-primary" />
                  <span>GoBD Compliant</span>
                </div>
                <div className="flex items-center gap-2">
                  <CheckCircle2 className="h-5 w-5 text-primary" />
                  <span>DATEV Compatible</span>
                </div>
                <div className="flex items-center gap-2">
                  <CheckCircle2 className="h-5 w-5 text-primary" />
                  <span>ELSTER Ready</span>
                </div>
              </div>
            </div>

            {/* Right Column - Stats Cards */}
            <div className="relative animate-[slideInRight_0.8s_ease-out]">
              <div className="grid grid-cols-2 gap-4">
                {/* Card 1 */}
                <div
                  className="bg-card border border-border rounded-2xl p-6 shadow-lg hover:shadow-xl transition-all hover:-translate-y-1"
                  style={{ animationDelay: '0.1s' }}
                >
                  <BarChart3 className="h-8 w-8 text-primary mb-4" />
                  <div className="text-4xl font-bold mb-2" style={{ fontFamily: 'var(--font-display)' }}>
                    100%
                  </div>
                  <div className="text-sm text-muted-foreground" style={{ fontFamily: 'var(--font-body)' }}>
                    Automated VAT Calculation
                  </div>
                </div>

                {/* Card 2 */}
                <div
                  className="bg-card border border-border rounded-2xl p-6 shadow-lg hover:shadow-xl transition-all hover:-translate-y-1 mt-8"
                  style={{ animationDelay: '0.2s' }}
                >
                  <FileText className="h-8 w-8 text-primary mb-4" />
                  <div className="text-4xl font-bold mb-2" style={{ fontFamily: 'var(--font-display)' }}>
                    2 min
                  </div>
                  <div className="text-sm text-muted-foreground" style={{ fontFamily: 'var(--font-body)' }}>
                    Average Booking Time
                  </div>
                </div>

                {/* Card 3 */}
                <div
                  className="bg-primary text-primary-foreground rounded-2xl p-6 shadow-lg hover:shadow-xl transition-all hover:-translate-y-1"
                  style={{ animationDelay: '0.3s' }}
                >
                  <Calendar className="h-8 w-8 mb-4 opacity-90" />
                  <div className="text-4xl font-bold mb-2" style={{ fontFamily: 'var(--font-display)' }}>
                    24/7
                  </div>
                  <div className="text-sm opacity-90" style={{ fontFamily: 'var(--font-body)' }}>
                    Bank Synchronization
                  </div>
                </div>

                {/* Card 4 */}
                <div
                  className="bg-card border border-border rounded-2xl p-6 shadow-lg hover:shadow-xl transition-all hover:-translate-y-1 -mt-8"
                  style={{ animationDelay: '0.4s' }}
                >
                  <Shield className="h-8 w-8 text-primary mb-4" />
                  <div className="text-4xl font-bold mb-2" style={{ fontFamily: 'var(--font-display)' }}>
                    256bit
                  </div>
                  <div className="text-sm text-muted-foreground" style={{ fontFamily: 'var(--font-body)' }}>
                    Bank-Grade Encryption
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Features Section - Asymmetric Grid */}
      <section className="py-24 bg-muted/30">
        <div className="max-w-7xl mx-auto px-6 lg:px-8">
          <div className="text-center mb-20">
            <h2
              className="text-5xl lg:text-6xl font-bold mb-6 tracking-tight"
              style={{ fontFamily: 'var(--font-display)' }}
            >
              Everything You Need.
              <br />
              <span className="text-primary">Nothing You Don't.</span>
            </h2>
            <p
              className="text-xl text-muted-foreground max-w-2xl mx-auto"
              style={{ fontFamily: 'var(--font-body)' }}
            >
              Built specifically for German accounting standards.
              No compromises, no workarounds.
            </p>
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
            {features.map((feature, index) => (
              <div
                key={index}
                className={`
                  group relative bg-card border border-border rounded-2xl p-8
                  hover:border-primary/50 transition-all hover:shadow-lg
                  ${index === 0 ? 'lg:col-span-2' : ''}
                  ${index === 3 ? 'lg:col-span-2' : ''}
                `}
                style={{
                  animation: `fadeInUp 0.6s ease-out ${index * 0.1}s both`
                }}
              >
                <div className="flex items-start gap-4">
                  <div className="p-3 bg-primary/10 rounded-xl group-hover:bg-primary/20 transition-colors">
                    <feature.icon className="h-6 w-6 text-primary" />
                  </div>
                  <div className="flex-1">
                    <h3
                      className="text-xl font-bold mb-3"
                      style={{ fontFamily: 'var(--font-display)' }}
                    >
                      {feature.title}
                    </h3>
                    <p
                      className="text-muted-foreground leading-relaxed"
                      style={{ fontFamily: 'var(--font-body)' }}
                    >
                      {feature.description}
                    </p>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-24 relative overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-br from-primary/10 via-background to-green-500/10" />

        <div className="relative max-w-4xl mx-auto px-6 lg:px-8 text-center">
          <h2
            className="text-5xl lg:text-6xl font-bold mb-6 tracking-tight"
            style={{ fontFamily: 'var(--font-display)' }}
          >
            Ready to Streamline
            <br />
            Your <span className="text-primary">Accounting?</span>
          </h2>

          <p
            className="text-xl text-muted-foreground mb-10 max-w-2xl mx-auto"
            style={{ fontFamily: 'var(--font-body)' }}
          >
            Join German businesses who've simplified their bookkeeping
            with BilanzBlitz. Start your free trial today.
          </p>

          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Link href="/users/sign_up">
              <Button size="lg" className="text-lg px-10 py-6 shadow-xl shadow-primary/20">
                Start Free Trial
                <ArrowRight className="ml-2 h-5 w-5" />
              </Button>
            </Link>
            <Link href="/users/sign_in">
              <Button size="lg" variant="outline" className="text-lg px-10 py-6">
                Sign In
              </Button>
            </Link>
          </div>

          <p className="mt-8 text-sm text-muted-foreground">
            No credit card required • 14-day free trial • Cancel anytime
          </p>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-border bg-muted/30">
        <div className="max-w-7xl mx-auto px-6 lg:px-8 py-12">
          <div className="grid md:grid-cols-4 gap-8">
            <div className="md:col-span-2">
              <div className="text-2xl font-bold mb-4" style={{ fontFamily: 'var(--font-display)' }}>
                Bilanz<span className="text-primary">Blitz</span>
              </div>
              <p className="text-muted-foreground max-w-sm" style={{ fontFamily: 'var(--font-body)' }}>
                Professional accounting software for German businesses.
                GoBD-compliant, DATEV-compatible, ELSTER-ready.
              </p>
            </div>

            <div>
              <h4 className="font-semibold mb-4" style={{ fontFamily: 'var(--font-display)' }}>Product</h4>
              <ul className="space-y-2 text-sm text-muted-foreground" style={{ fontFamily: 'var(--font-body)' }}>
                <li><a href="#" className="hover:text-primary transition-colors">Features</a></li>
                <li><a href="#" className="hover:text-primary transition-colors">Pricing</a></li>
                <li><a href="#" className="hover:text-primary transition-colors">Security</a></li>
              </ul>
            </div>

            <div>
              <h4 className="font-semibold mb-4" style={{ fontFamily: 'var(--font-display)' }}>Company</h4>
              <ul className="space-y-2 text-sm text-muted-foreground" style={{ fontFamily: 'var(--font-body)' }}>
                <li><a href="#" className="hover:text-primary transition-colors">About</a></li>
                <li><a href="#" className="hover:text-primary transition-colors">Contact</a></li>
                <li><a href="#" className="hover:text-primary transition-colors">Legal</a></li>
              </ul>
            </div>
          </div>

          <div className="border-t border-border mt-12 pt-8 text-center text-sm text-muted-foreground">
            <p style={{ fontFamily: 'var(--font-body)' }}>
              © 2025 BilanzBlitz. All rights reserved.
            </p>
          </div>
        </div>
      </footer>

      {/* Custom Animations */}
      <style>{`
        @keyframes slideInLeft {
          from {
            opacity: 0;
            transform: translateX(-30px);
          }
          to {
            opacity: 1;
            transform: translateX(0);
          }
        }

        @keyframes slideInRight {
          from {
            opacity: 0;
            transform: translateX(30px);
          }
          to {
            opacity: 1;
            transform: translateX(0);
          }
        }

        @keyframes fadeInUp {
          from {
            opacity: 0;
            transform: translateY(20px);
          }
          to {
            opacity: 1;
            transform: translateY(0);
          }
        }
      `}</style>
    </div>
  )
}

const features = [
  {
    icon: BarChart3,
    title: 'Automated Bank Sync',
    description: 'Connect your bank accounts and import transactions automatically. Support for all major German banks via FinTS/HBCI and PSD2.',
  },
  {
    icon: FileText,
    title: 'Smart Receipt Management',
    description: 'Upload receipts and invoices with automatic OCR. Extract data instantly and link to bookings.',
  },
  {
    icon: Calendar,
    title: 'Transaction Splitting',
    description: 'Split complex transactions across multiple accounts. Separate VAT automatically with intelligent categorization.',
  },
  {
    icon: CheckCircle2,
    title: 'VAT Reports (UStVA)',
    description: 'Generate monthly or quarterly VAT pre-registrations automatically. Export directly to ELSTER for seamless filing.',
  },
  {
    icon: Shield,
    title: 'GoBD Compliance',
    description: 'Immutable posted entries, complete audit trails, and fiscal year closing. Built for German tax law from the ground up.',
  },
  {
    icon: FileText,
    title: 'Annual Tax Returns',
    description: 'Prepare comprehensive annual filings with balance sheets and P&L statements. DATEV export included.',
  },
]
