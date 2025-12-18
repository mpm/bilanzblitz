import { Badge } from '@/components/ui/badge'
import { FileText, Building } from 'lucide-react'

interface ReportTypeBadgeProps {
  reportType: 'ustva' | 'kst' | 'zusammenfassende_meldung' | 'umsatzsteuer' | 'gewerbesteuer'
}

export function ReportTypeBadge({ reportType }: ReportTypeBadgeProps) {
  const config = {
    ustva: {
      label: 'UStVA',
      icon: FileText,
      variant: 'default' as const,
      className: 'bg-blue-100 text-blue-800 hover:bg-blue-200'
    },
    kst: {
      label: 'KSt',
      icon: Building,
      variant: 'secondary' as const,
      className: 'bg-green-100 text-green-800 hover:bg-green-200'
    },
    zusammenfassende_meldung: {
      label: 'ZM',
      icon: FileText,
      variant: 'outline' as const,
      className: ''
    },
    umsatzsteuer: {
      label: 'USt',
      icon: FileText,
      variant: 'outline' as const,
      className: ''
    },
    gewerbesteuer: {
      label: 'GewSt',
      icon: Building,
      variant: 'outline' as const,
      className: ''
    }
  }

  const { label, icon: Icon, className } = config[reportType] || config.ustva

  return (
    <Badge variant="outline" className={className}>
      <Icon className="w-3 h-3 mr-1" />
      {label}
    </Badge>
  )
}
