import { Head, Link, useForm } from '@inertiajs/react'
import { FormEvent } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card'
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
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-green-50 to-green-100 dark:from-green-950 dark:to-green-900 p-4">
      <Head title="Sign Up" />

      <Card className="w-full max-w-md">
        <CardHeader className="space-y-1">
          <CardTitle className="text-3xl font-bold text-center">Create Account</CardTitle>
          <CardDescription className="text-center">
            Get started with BilanzBlitz for free
          </CardDescription>
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

          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="email">Email</Label>
              <Input
                id="email"
                type="email"
                placeholder="you@example.com"
                value={data.email}
                onChange={e => setData('email', e.target.value)}
                required
                autoComplete="email"
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="password">Password</Label>
              <Input
                id="password"
                type="password"
                placeholder="••••••••"
                value={data.password}
                onChange={e => setData('password', e.target.value)}
                required
                autoComplete="new-password"
              />
              <p className="text-xs text-muted-foreground">
                Must be at least 6 characters
              </p>
            </div>

            <div className="space-y-2">
              <Label htmlFor="password_confirmation">Confirm Password</Label>
              <Input
                id="password_confirmation"
                type="password"
                placeholder="••••••••"
                value={data.password_confirmation}
                onChange={e => setData('password_confirmation', e.target.value)}
                required
                autoComplete="new-password"
              />
            </div>

            <Button
              type="submit"
              className="w-full"
              disabled={processing}
            >
              {processing ? 'Creating account...' : 'Create Account'}
            </Button>
          </form>
        </CardContent>

        <CardFooter className="flex flex-col space-y-4">
          <div className="text-sm text-center text-muted-foreground">
            Already have an account?{' '}
            <Link
              href="/users/sign_in"
              className="text-primary font-medium hover:underline"
            >
              Sign in
            </Link>
          </div>
        </CardFooter>
      </Card>
    </div>
  )
}
