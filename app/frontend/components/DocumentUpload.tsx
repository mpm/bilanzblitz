import { useState, useRef } from 'react'
import { Card, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Upload, AlertCircle } from 'lucide-react'
import { cn } from '@/lib/utils'

interface DocumentUploadProps {
  onUpload: (files: File[]) => Promise<void>
  accept?: string
  maxSizeBytes?: number
  multiple?: boolean
  compact?: boolean
  disabled?: boolean
  className?: string
}

export function DocumentUpload({
  onUpload,
  accept = '.pdf,application/pdf',
  maxSizeBytes = 10 * 1024 * 1024, // 10MB default
  multiple = true,
  compact = false,
  disabled = false,
  className,
}: DocumentUploadProps) {
  const [isDragging, setIsDragging] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const validateFile = (file: File): string | null => {
    if (!file.type.includes('pdf') && !file.name.toLowerCase().endsWith('.pdf')) {
      return 'File must be a PDF'
    }
    if (file.size > maxSizeBytes) {
      return `File size exceeds ${maxSizeBytes / 1024 / 1024}MB limit`
    }
    return null
  }

  const handleFiles = async (files: FileList | null) => {
    if (!files || files.length === 0) return

    setError(null)
    const fileArray = Array.from(files)

    // Validate all files
    for (const file of fileArray) {
      const validationError = validateFile(file)
      if (validationError) {
        setError(validationError)
        return
      }
    }

    // Upload files
    try {
      await onUpload(fileArray)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Upload failed, please try again')
    }
  }

  const handleDragEnter = (e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    if (!disabled) {
      setIsDragging(true)
    }
  }

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
  }

  const handleDragLeave = (e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    setIsDragging(false)
  }

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    setIsDragging(false)

    if (disabled) return

    const { files } = e.dataTransfer
    handleFiles(files)
  }

  const handleClick = () => {
    if (!disabled) {
      fileInputRef.current?.click()
    }
  }

  const handleFileInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    handleFiles(e.target.files)
  }

  if (compact) {
    return (
      <div className={cn('space-y-2', className)}>
        <div
          className={cn(
            'relative rounded-lg border-2 border-dashed p-4 transition-colors cursor-pointer',
            isDragging
              ? 'border-primary bg-primary/5'
              : 'border-muted-foreground/25 hover:border-primary/50',
            disabled && 'opacity-50 cursor-not-allowed'
          )}
          onDragEnter={handleDragEnter}
          onDragOver={handleDragOver}
          onDragLeave={handleDragLeave}
          onDrop={handleDrop}
          onClick={handleClick}
        >
          <div className="flex items-center gap-3">
            <div className="rounded-full bg-primary/10 p-2">
              <Upload className="h-4 w-4 text-primary" />
            </div>
            <div className="flex-1">
              <p className="text-sm font-medium">
                Drop PDF here or click to browse
              </p>
              <p className="text-xs text-muted-foreground">
                Max {maxSizeBytes / 1024 / 1024}MB
              </p>
            </div>
          </div>
          <input
            ref={fileInputRef}
            type="file"
            accept={accept}
            multiple={multiple}
            onChange={handleFileInputChange}
            className="hidden"
            disabled={disabled}
          />
        </div>
        {error && (
          <Alert variant="destructive">
            <AlertCircle className="h-4 w-4" />
            <AlertDescription>{error}</AlertDescription>
          </Alert>
        )}
      </div>
    )
  }

  return (
    <div className={cn('space-y-4', className)}>
      <Card>
        <CardContent className="pt-6">
          <div
            className={cn(
              'relative rounded-lg border-2 border-dashed p-12 transition-colors cursor-pointer',
              isDragging
                ? 'border-primary bg-primary/5'
                : 'border-muted-foreground/25 hover:border-primary/50',
              disabled && 'opacity-50 cursor-not-allowed'
            )}
            onDragEnter={handleDragEnter}
            onDragOver={handleDragOver}
            onDragLeave={handleDragLeave}
            onDrop={handleDrop}
            onClick={handleClick}
          >
            <div className="flex flex-col items-center justify-center space-y-4">
              <div className="rounded-full bg-primary/10 p-4">
                <Upload className="h-8 w-8 text-primary" />
              </div>
              <div className="text-center">
                <p className="text-lg font-medium">
                  Drop PDF files here or click to browse
                </p>
                <p className="text-sm text-muted-foreground mt-1">
                  {multiple ? 'Multiple files supported' : 'Single file upload'} · Max {maxSizeBytes / 1024 / 1024}MB per file
                </p>
              </div>
              <Button type="button" variant="secondary" disabled={disabled}>
                Select Files
              </Button>
            </div>
            <input
              ref={fileInputRef}
              type="file"
              accept={accept}
              multiple={multiple}
              onChange={handleFileInputChange}
              className="hidden"
              disabled={disabled}
            />
          </div>
        </CardContent>
      </Card>
      {error && (
        <Alert variant="destructive">
          <AlertCircle className="h-4 w-4" />
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}
    </div>
  )
}
