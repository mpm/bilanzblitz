import { Head, Link, useForm } from '@inertiajs/react'
import { FormEvent } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { AlertCircle } from 'lucide-react'

interface RegisterProps {
  errors?: string[]
}

export default function Register({ errors }: RegisterProps) {
  const { data, setData, post, processing } = useForm({
    email: '',
    password: '',
    password_confirmation: '',
  })

  function handleSubmit(e: FormEvent) {
    e.preventDefault()
    post('/users')
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-muted/30 p-4">
      <Head title="Sign Up - BilanzBlitz" />

      <div className="w-full max-w-sm">
        {/* Logo */}
        <div className="text-center mb-8">
          <h1 className="text-2xl font-semibold tracking-tight mb-1">
            Bilanz<span className="text-primary">Blitz</span>
          </h1>
          <p className="text-sm text-muted-foreground">
            Create your account
          </p>
        </div>

        <Card>
          <CardHeader className="space-y-1 pb-4">
            <CardTitle className="text-xl">Get started free</CardTitle>
            <CardDescription>
              Start managing your accounting today
            </CardDescription>
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

            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="email" className="text-sm font-medium">
                  Email
                </Label>
                <Input
                  id="email"
                  type="email"
                  placeholder="name@company.com"
                  value={data.email}
                  onChange={e => setData('email', e.target.value)}
                  required
                  autoComplete="email"
                  className="h-9"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="password" className="text-sm font-medium">
                  Password
                </Label>
                <Input
                  id="password"
                  type="password"
                  value={data.password}
                  onChange={e => setData('password', e.target.value)}
                  required
                  autoComplete="new-password"
                  className="h-9"
                />
                <p className="text-xs text-muted-foreground">
                  Must be at least 6 characters
                </p>
              </div>

              <div className="space-y-2">
                <Label htmlFor="password_confirmation" className="text-sm font-medium">
                  Confirm password
                </Label>
                <Input
                  id="password_confirmation"
                  type="password"
                  value={data.password_confirmation}
                  onChange={e => setData('password_confirmation', e.target.value)}
                  required
                  autoComplete="new-password"
                  className="h-9"
                />
              </div>

              <Button
                type="submit"
                className="w-full"
                disabled={processing}
              >
                {processing ? 'Creating account...' : 'Create account'}
              </Button>
            </form>

            <div className="mt-6 text-center text-sm">
              <span className="text-muted-foreground">Already have an account? </span>
              <Link
                href="/users/sign_in"
                className="text-primary font-medium hover:underline"
              >
                Sign in
              </Link>
            </div>
          </CardContent>
        </Card>

        <p className="mt-8 text-center text-xs text-muted-foreground">
          By signing up, you agree to our Terms of Service and Privacy Policy
        </p>
      </div>
    </div>
  )
}
