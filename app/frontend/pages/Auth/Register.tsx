import { Head, useForm } from '@inertiajs/react'
import { FormEvent } from 'react'

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
    <div style={{ maxWidth: '400px', margin: '100px auto', padding: '20px' }}>
      <Head title="Sign Up" />

      <h1 style={{ marginBottom: '30px', textAlign: 'center' }}>Sign Up</h1>

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
          <label htmlFor="password_confirmation" style={{ display: 'block', marginBottom: '5px' }}>
            Confirm Password
          </label>
          <input
            id="password_confirmation"
            type="password"
            value={data.password_confirmation}
            onChange={e => setData('password_confirmation', e.target.value)}
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
          {processing ? 'Signing up...' : 'Sign Up'}
        </button>

        <p style={{ marginTop: '20px', textAlign: 'center' }}>
          Already have an account?{' '}
          <a href="/users/sign_in" style={{ color: '#007bff' }}>
            Sign in
          </a>
        </p>
      </form>
    </div>
  )
}
