import { Head, useForm } from '@inertiajs/react'
import { FormEvent } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { AlertCircle, Building2, CheckCircle2 } from 'lucide-react'

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
    <div className="min-h-screen flex items-center justify-center bg-muted/30 p-4">
      <Head title="Company Setup - BilanzBlitz" />

      <div className="w-full max-w-2xl">
        {/* Header */}
        <div className="text-center mb-8">
          <h1 className="text-2xl font-semibold tracking-tight mb-1">
            Bilanz<span className="text-primary">Blitz</span>
          </h1>
          <p className="text-sm text-muted-foreground">
            One more step to get started
          </p>
        </div>

        <Card>
          <CardHeader className="space-y-1">
            <div className="flex items-center gap-3">
              <div className="h-10 w-10 rounded-full bg-primary/10 flex items-center justify-center">
                <Building2 className="h-5 w-5 text-primary" />
              </div>
              <div>
                <CardTitle className="text-xl">Set up your company</CardTitle>
                <CardDescription>
                  We'll create everything you need to get started
                </CardDescription>
              </div>
            </div>
          </CardHeader>

          <CardContent>
            {errors && errors.length > 0 && (
              <Alert variant="destructive" className="mb-4">
                <AlertCircle className="h-4 w-4" />
                <AlertDescription className="text-sm">
                  {errors.map((error, index) => (
                    <div key={index}>{error}</div>
                  ))}
                </AlertDescription>
              </Alert>
            )}

            <form onSubmit={handleSubmit} className="space-y-6">
              <div className="space-y-2">
                <Label htmlFor="company_name" className="text-sm font-medium">
                  Company name
                </Label>
                <Input
                  id="company_name"
                  type="text"
                  placeholder="e.g., Acme GmbH"
                  value={data.company.name}
                  onChange={e => setData('company', { name: e.target.value })}
                  required
                  autoFocus
                  className="h-9"
                />
                <p className="text-xs text-muted-foreground">
                  You can add more details like tax numbers and addresses later
                </p>
              </div>

              {/* What we'll create */}
              <div className="rounded-lg border bg-muted/30 p-4">
                <h3 className="text-sm font-medium mb-3">
                  We'll automatically set up:
                </h3>
                <ul className="space-y-2 text-sm text-muted-foreground">
                  <li className="flex items-center gap-2">
                    <CheckCircle2 className="h-4 w-4 text-primary" />
                    Your company profile
                  </li>
                  <li className="flex items-center gap-2">
                    <CheckCircle2 className="h-4 w-4 text-primary" />
                    Current fiscal year ({new Date().getFullYear()})
                  </li>
                  <li className="flex items-center gap-2">
                    <CheckCircle2 className="h-4 w-4 text-primary" />
                    A generic bank account to get started
                  </li>
                  <li className="flex items-center gap-2">
                    <CheckCircle2 className="h-4 w-4 text-primary" />
                    Basic chart of accounts (SKR03)
                  </li>
                </ul>
              </div>

              <Button
                type="submit"
                className="w-full"
                disabled={processing || !data.company.name.trim()}
              >
                {processing ? 'Setting up...' : 'Create company'}
              </Button>
            </form>
          </CardContent>
        </Card>

        <p className="mt-6 text-center text-xs text-muted-foreground">
          You can always update these details or add more companies later
        </p>
      </div>
    </div>
  )
}
