import { Head, Link, useForm } from '@inertiajs/react'
import { FormEvent } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Checkbox } from '@/components/ui/checkbox'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { AlertCircle } from 'lucide-react'

interface LoginProps {
  errors?: string[]
}

export default function Login({ errors }: LoginProps) {
  const { data, setData, post, processing } = useForm({
    email: '',
    password: '',
    remember_me: false,
  })

  function handleSubmit(e: FormEvent) {
    e.preventDefault()
    post('/users/sign_in')
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-muted/30 p-4">
      <Head title="Sign In - BilanzBlitz" />

      <div className="w-full max-w-sm">
        {/* Logo */}
        <div className="text-center mb-8">
          <h1 className="text-2xl font-semibold tracking-tight mb-1">
            Bilanz<span className="text-primary">Blitz</span>
          </h1>
          <p className="text-sm text-muted-foreground">
            Sign in to your account
          </p>
        </div>

        <Card>
          <CardHeader className="space-y-1 pb-4">
            <CardTitle className="text-xl">Welcome back</CardTitle>
            <CardDescription>
              Enter your credentials to continue
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
                  autoComplete="current-password"
                  className="h-9"
                />
              </div>

              <div className="flex items-center space-x-2">
                <Checkbox
                  id="remember_me"
                  checked={data.remember_me}
                  onCheckedChange={(checked) => setData('remember_me', checked === true)}
                />
                <Label
                  htmlFor="remember_me"
                  className="text-sm font-normal cursor-pointer text-muted-foreground"
                >
                  Remember me for 30 days
                </Label>
              </div>

              <Button
                type="submit"
                className="w-full"
                disabled={processing}
              >
                {processing ? 'Signing in...' : 'Sign in'}
              </Button>
            </form>

            <div className="mt-6 text-center text-sm">
              <span className="text-muted-foreground">Don't have an account? </span>
              <Link
                href="/users/sign_up"
                className="text-primary font-medium hover:underline"
              >
                Sign up
              </Link>
            </div>
          </CardContent>
        </Card>

        <p className="mt-8 text-center text-xs text-muted-foreground">
          By signing in, you agree to our Terms of Service and Privacy Policy
        </p>
      </div>
    </div>
  )
}
