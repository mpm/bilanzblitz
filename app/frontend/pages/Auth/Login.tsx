import { Head, Link, useForm } from '@inertiajs/react'
import { FormEvent } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card'
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
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-green-50 to-green-100 dark:from-green-950 dark:to-green-900 p-4">
      <Head title="Sign In" />

      <Card className="w-full max-w-md">
        <CardHeader className="space-y-1">
          <CardTitle className="text-3xl font-bold text-center">BilanzBlitz</CardTitle>
          <CardDescription className="text-center">
            Sign in to your accounting dashboard
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
                autoComplete="current-password"
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
                className="text-sm font-normal cursor-pointer"
              >
                Remember me
              </Label>
            </div>

            <Button
              type="submit"
              className="w-full"
              disabled={processing}
            >
              {processing ? 'Signing in...' : 'Sign In'}
            </Button>
          </form>
        </CardContent>

        <CardFooter className="flex flex-col space-y-4">
          <div className="text-sm text-center text-muted-foreground">
            Don't have an account?{' '}
            <Link
              href="/users/sign_up"
              className="text-primary font-medium hover:underline"
            >
              Sign up
            </Link>
          </div>
        </CardFooter>
      </Card>
    </div>
  )
}
