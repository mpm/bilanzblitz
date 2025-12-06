import { Head, useForm } from '@inertiajs/react'
import { FormEvent } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { AlertCircle, Building2, Sparkles } from 'lucide-react'

interface CompanySetupProps {
  errors?: string[]
}

export default function CompanySetup({ errors }: CompanySetupProps) {
  const { data, setData, post, processing } = useForm({
    company: {
      name: '',
    }
  })

  function handleSubmit(e: FormEvent) {
    e.preventDefault()
    post('/onboarding')
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-green-50 to-green-100 dark:from-green-950 dark:to-green-900 p-4">
      <Head title="Company Setup - BilanzBlitz" />

      <div className="w-full max-w-2xl">
        {/* Progress Indicator */}
        <div className="mb-8 text-center">
          <div className="inline-flex items-center gap-2 px-4 py-2 bg-primary/10 rounded-full mb-4">
            <Sparkles className="h-4 w-4 text-primary" />
            <span className="text-sm font-semibold text-primary" style={{ fontFamily: 'var(--font-display)' }}>
              Welcome to BilanzBlitz
            </span>
          </div>
          <h1
            className="text-4xl font-bold mb-2"
            style={{ fontFamily: 'var(--font-display)' }}
          >
            Let's Set Up Your Company
          </h1>
          <p
            className="text-muted-foreground"
            style={{ fontFamily: 'var(--font-body)' }}
          >
            Just one quick step to get started
          </p>
        </div>

        <Card className="shadow-xl">
          <CardHeader className="space-y-1">
            <div className="flex items-center gap-3">
              <div className="p-3 bg-primary/10 rounded-xl">
                <Building2 className="h-6 w-6 text-primary" />
              </div>
              <div>
                <CardTitle className="text-2xl" style={{ fontFamily: 'var(--font-display)' }}>
                  Company Details
                </CardTitle>
                <CardDescription style={{ fontFamily: 'var(--font-body)' }}>
                  We'll create your first company and set up the basics
                </CardDescription>
              </div>
            </div>
          </CardHeader>

          <CardContent>
            {errors && errors.length > 0 && (
              <Alert variant="destructive" className="mb-6">
                <AlertCircle className="h-4 w-4" />
                <AlertDescription>
                  {errors.map((error, index) => (
                    <p key={index}>{error}</p>
                  ))}
                </AlertDescription>
              </Alert>
            )}

            <form onSubmit={handleSubmit} className="space-y-6">
              <div className="space-y-2">
                <Label htmlFor="company_name" className="text-base">
                  Company Name <span className="text-destructive">*</span>
                </Label>
                <Input
                  id="company_name"
                  type="text"
                  placeholder="e.g., Acme GmbH"
                  value={data.company.name}
                  onChange={e => setData('company', { name: e.target.value })}
                  required
                  autoFocus
                  className="text-base h-12"
                  style={{ fontFamily: 'var(--font-body)' }}
                />
                <p className="text-sm text-muted-foreground" style={{ fontFamily: 'var(--font-body)' }}>
                  You can add more details like tax numbers and address later
                </p>
              </div>

              {/* What we'll create info box */}
              <div className="bg-muted/50 rounded-lg p-4 border border-border">
                <h3
                  className="font-semibold mb-3 flex items-center gap-2"
                  style={{ fontFamily: 'var(--font-display)' }}
                >
                  <Sparkles className="h-4 w-4 text-primary" />
                  We'll automatically set up:
                </h3>
                <ul className="space-y-2 text-sm" style={{ fontFamily: 'var(--font-body)' }}>
                  <li className="flex items-start gap-2">
                    <span className="text-primary mt-0.5">✓</span>
                    <span>Your company profile</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <span className="text-primary mt-0.5">✓</span>
                    <span>Current fiscal year ({new Date().getFullYear()})</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <span className="text-primary mt-0.5">✓</span>
                    <span>A generic bank account to get started</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <span className="text-primary mt-0.5">✓</span>
                    <span>Basic chart of accounts (SKR03)</span>
                  </li>
                </ul>
              </div>

              <Button
                type="submit"
                className="w-full h-12 text-base"
                disabled={processing || !data.company.name.trim()}
                style={{ fontFamily: 'var(--font-display)' }}
              >
                {processing ? 'Setting up your company...' : 'Create Company & Continue'}
              </Button>
            </form>
          </CardContent>
        </Card>

        {/* Footer note */}
        <p className="mt-6 text-center text-sm text-muted-foreground" style={{ fontFamily: 'var(--font-body)' }}>
          You can always update these details or add more companies later
        </p>
      </div>
    </div>
  )
}
