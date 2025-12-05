import { Head, useForm } from '@inertiajs/react'
import { FormEvent } from 'react'

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
    <div style={{ maxWidth: '400px', margin: '100px auto', padding: '20px' }}>
      <Head title="Sign In" />

      <h1 style={{ marginBottom: '30px', textAlign: 'center' }}>Sign In</h1>

      {errors && errors.length > 0 && (
        <div style={{
          backgroundColor: '#fee',
          border: '1px solid #fcc',
          borderRadius: '4px',
          padding: '10px',
          marginBottom: '20px'
        }}>
          {errors.map((error, index) => (
            <p key={index} style={{ margin: '5px 0', color: '#c00' }}>{error}</p>
          ))}
        </div>
      )}

      <form onSubmit={handleSubmit}>
        <div style={{ marginBottom: '15px' }}>
          <label htmlFor="email" style={{ display: 'block', marginBottom: '5px' }}>
            Email
          </label>
          <input
            id="email"
            type="email"
            value={data.email}
            onChange={e => setData('email', e.target.value)}
            required
            style={{
              width: '100%',
              padding: '8px',
              fontSize: '16px',
              border: '1px solid #ddd',
              borderRadius: '4px'
            }}
          />
        </div>

        <div style={{ marginBottom: '15px' }}>
          <label htmlFor="password" style={{ display: 'block', marginBottom: '5px' }}>
            Password
          </label>
          <input
            id="password"
            type="password"
            value={data.password}
            onChange={e => setData('password', e.target.value)}
            required
            style={{
              width: '100%',
              padding: '8px',
              fontSize: '16px',
              border: '1px solid #ddd',
              borderRadius: '4px'
            }}
          />
        </div>

        <div style={{ marginBottom: '20px' }}>
          <label style={{ display: 'flex', alignItems: 'center', cursor: 'pointer' }}>
            <input
              type="checkbox"
              checked={data.remember_me}
              onChange={e => setData('remember_me', e.target.checked)}
              style={{ marginRight: '8px' }}
            />
            Remember me
          </label>
        </div>

        <button
          type="submit"
          disabled={processing}
          style={{
            width: '100%',
            padding: '10px',
            fontSize: '16px',
            backgroundColor: '#007bff',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: processing ? 'not-allowed' : 'pointer',
            opacity: processing ? 0.7 : 1
          }}
        >
          {processing ? 'Signing in...' : 'Sign In'}
        </button>

        <p style={{ marginTop: '20px', textAlign: 'center' }}>
          Don't have an account?{' '}
          <a href="/users/sign_up" style={{ color: '#007bff' }}>
            Sign up
          </a>
        </p>
      </form>
    </div>
  )
}
