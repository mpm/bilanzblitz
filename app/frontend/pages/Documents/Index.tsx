import { useState } from 'react'
import { Head, router } from '@inertiajs/react'
import { AppLayout } from '@/components/AppLayout'
import { DocumentUpload } from '@/components/DocumentUpload'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { FileText, Download, Trash2, Link as LinkIcon, Loader2 } from 'lucide-react'

interface Document {
  id: number
  documentType: string | null
  documentDate: string | null
  documentNumber: string | null
  issuerName: string | null
  totalAmount: number | null
  processingStatus: string
  fileName: string | null
  fileSize: number | null
  fileUrl: string | null
  thumbnailUrl: string | null
  linkedToJournal: boolean
  journalEntryCount: number
  createdAt: string
}

interface DocumentsIndexProps {
  company: {
    id: number
    name: string
  }
  documents: Document[]
}

export default function DocumentsIndex({ company, documents }: DocumentsIndexProps) {
  const [uploading, setUploading] = useState(false)
  const [filterType, setFilterType] = useState<string>('all')
  const [filterLinked, setFilterLinked] = useState<string>('all')

  const getCsrfToken = (): string => {
    return document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
  }

  const formatFileSize = (bytes: number): string => {
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
    return `${(bytes / 1024 / 1024).toFixed(1)} MB`
  }

  const formatDate = (dateString: string | null): string => {
    if (!dateString) return '-'
    return new Date(dateString).toLocaleDateString('de-DE')
  }

  const formatCurrency = (amount: number | null): string => {
    if (amount === null) return '-'
    return new Intl.NumberFormat('de-DE', {
      style: 'currency',
      currency: 'EUR',
    }).format(amount)
  }

  const getDocumentTypeBadgeVariant = (type: string | null) => {
    switch (type) {
      case 'invoice':
        return 'default'
      case 'receipt':
        return 'secondary'
      case 'credit_note':
        return 'outline'
      default:
        return 'outline'
    }
  }

  const getDocumentTypeLabel = (type: string | null): string => {
    switch (type) {
      case 'invoice':
        return 'Invoice'
      case 'receipt':
        return 'Receipt'
      case 'credit_note':
        return 'Credit Note'
      case 'contract':
        return 'Contract'
      case 'other':
        return 'Other'
      default:
        return '-'
    }
  }

  const handleUpload = async (files: File[]) => {
    setUploading(true)

    try {
      for (const file of files) {
        const formData = new FormData()
        formData.append('document[file]', file)
        formData.append('document[processing_status]', 'ready')

        const response = await fetch('/documents', {
          method: 'POST',
          headers: {
            'X-CSRF-Token': getCsrfToken(),
          },
          body: formData,
        })

        if (!response.ok) {
          const data = await response.json()
          throw new Error(data.errors?.[0] || 'Upload failed')
        }
      }

      // Refresh the page to show new documents
      router.reload()
    } catch (error) {
      alert(error instanceof Error ? error.message : 'Upload failed, please try again')
    } finally {
      setUploading(false)
    }
  }

  const handleDelete = async (documentId: number) => {
    if (!confirm('Are you sure you want to delete this document?')) return

    try {
      const response = await fetch(`/documents/${documentId}`, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': getCsrfToken(),
        },
      })

      if (!response.ok) {
        const data = await response.json()
        alert(data.errors?.[0] || 'Delete failed')
        return
      }

      router.reload()
    } catch (error) {
      alert('Delete failed')
    }
  }

  const handleDownload = (fileUrl: string) => {
    window.open(fileUrl, '_blank')
  }

  const handleFilterChange = (type: string, value: string) => {
    const params = new URLSearchParams()

    if (type === 'type') {
      setFilterType(value)
      if (value !== 'all') params.set('type', value)
      if (filterLinked === 'unlinked') params.set('linked', 'false')
    } else {
      setFilterLinked(value)
      if (filterType !== 'all') params.set('type', filterType)
      if (value === 'unlinked') params.set('linked', 'false')
    }

    const queryString = params.toString()
    router.visit(`/documents${queryString ? `?${queryString}` : ''}`, {
      preserveState: true,
      preserveScroll: true,
    })
  }

  return (
    <AppLayout company={company} currentPage="documents">
      <Head title={`Documents - ${company.name}`} />

      {/* Page Header */}
      <div className="mb-8">
        <h2 className="text-2xl font-semibold tracking-tight mb-1">
          Documents
        </h2>
        <p className="text-sm text-muted-foreground">
          Manage invoices, receipts, and other financial documents
        </p>
      </div>

      {/* Upload Area */}
      <div className="mb-6">
        <DocumentUpload
          onUpload={handleUpload}
          multiple={true}
          disabled={uploading}
        />
        {uploading && (
          <div className="flex items-center justify-center gap-2 mt-4 text-sm text-muted-foreground">
            <Loader2 className="h-4 w-4 animate-spin" />
            Uploading documents...
          </div>
        )}
      </div>

      {/* Filters */}
      <div className="flex items-center gap-4 mb-4">
        <div className="flex items-center gap-2">
          <label className="text-sm font-medium">Type:</label>
          <Select value={filterType} onValueChange={(value) => handleFilterChange('type', value)}>
            <SelectTrigger className="w-[180px]">
              <SelectValue placeholder="All Types" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Types</SelectItem>
              <SelectItem value="invoice">Invoice</SelectItem>
              <SelectItem value="receipt">Receipt</SelectItem>
              <SelectItem value="credit_note">Credit Note</SelectItem>
              <SelectItem value="contract">Contract</SelectItem>
              <SelectItem value="other">Other</SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div className="flex items-center gap-2">
          <label className="text-sm font-medium">Status:</label>
          <div className="flex gap-1">
            <Button
              variant={filterLinked === 'all' ? 'default' : 'outline'}
              size="sm"
              onClick={() => handleFilterChange('linked', 'all')}
            >
              All
            </Button>
            <Button
              variant={filterLinked === 'unlinked' ? 'default' : 'outline'}
              size="sm"
              onClick={() => handleFilterChange('linked', 'unlinked')}
            >
              Unlinked Only
            </Button>
          </div>
        </div>
      </div>

      {/* Documents Table */}
      {documents.length === 0 ? (
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-12">
            <div className="rounded-full bg-primary/10 p-3 mb-4">
              <FileText className="h-6 w-6 text-primary" />
            </div>
            <h3 className="font-semibold mb-1">No documents yet</h3>
            <p className="text-sm text-muted-foreground text-center max-w-sm">
              Upload your first document using the upload area above.
            </p>
          </CardContent>
        </Card>
      ) : (
        <Card>
          <CardHeader>
            <CardTitle>Your Documents</CardTitle>
            <CardDescription>
              {documents.length} {documents.length === 1 ? 'document' : 'documents'}
            </CardDescription>
          </CardHeader>
          <CardContent>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="w-[50px]"></TableHead>
                  <TableHead>Filename</TableHead>
                  <TableHead>Type</TableHead>
                  <TableHead>Date</TableHead>
                  <TableHead>Issuer</TableHead>
                  <TableHead className="text-right">Amount</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {documents.map((doc) => (
                  <TableRow key={doc.id}>
                    <TableCell>
                      <div className="rounded-full bg-primary/10 p-2">
                        <FileText className="h-4 w-4 text-primary" />
                      </div>
                    </TableCell>
                    <TableCell>
                      <div>
                        <div className="font-medium">{doc.fileName || 'Untitled'}</div>
                        {doc.fileSize && (
                          <div className="text-xs text-muted-foreground">
                            {formatFileSize(doc.fileSize)}
                          </div>
                        )}
                      </div>
                    </TableCell>
                    <TableCell>
                      <Badge variant={getDocumentTypeBadgeVariant(doc.documentType)}>
                        {getDocumentTypeLabel(doc.documentType)}
                      </Badge>
                    </TableCell>
                    <TableCell>{formatDate(doc.documentDate)}</TableCell>
                    <TableCell>{doc.issuerName || '-'}</TableCell>
                    <TableCell className="text-right">
                      {formatCurrency(doc.totalAmount)}
                    </TableCell>
                    <TableCell>
                      {doc.linkedToJournal ? (
                        <Badge variant="secondary" className="gap-1">
                          <LinkIcon className="h-3 w-3" />
                          Linked
                        </Badge>
                      ) : (
                        <Badge variant="outline">Not linked</Badge>
                      )}
                    </TableCell>
                    <TableCell className="text-right">
                      <div className="flex items-center justify-end gap-2">
                        {doc.fileUrl && (
                          <Button
                            variant="ghost"
                            size="icon"
                            className="h-8 w-8"
                            onClick={() => handleDownload(doc.fileUrl!)}
                          >
                            <Download className="h-4 w-4" />
                          </Button>
                        )}
                        <Button
                          variant="ghost"
                          size="icon"
                          className="h-8 w-8 text-destructive hover:text-destructive"
                          onClick={() => handleDelete(doc.id)}
                        >
                          <Trash2 className="h-4 w-4" />
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      )}
    </AppLayout>
  )
}
