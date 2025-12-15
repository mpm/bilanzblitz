import { Badge } from '@/components/ui/badge'
import { CheckCircle2, Circle, Lock } from 'lucide-react'

interface FiscalYearStatusBadgeProps {
  workflowState: 'open' | 'open_with_opening' | 'closing_posted' | 'closed'
  className?: string
}

export const FiscalYearStatusBadge = ({
  workflowState,
  className,
}: FiscalYearStatusBadgeProps) => {
  const configs = {
    open: {
      label: 'Open',
      variant: 'secondary' as const,
      icon: Circle,
      description: 'No opening balance',
    },
    open_with_opening: {
      label: 'Active',
      variant: 'default' as const,
      icon: CheckCircle2,
      description: 'Opening balance posted',
    },
    closing_posted: {
      label: 'Closing Posted',
      variant: 'outline' as const,
      icon: CheckCircle2,
      description: 'Ready to close',
    },
    closed: {
      label: 'Closed',
      variant: 'destructive' as const,
      icon: Lock,
      description: 'Fiscal year closed',
    },
  }

  const config = configs[workflowState] || configs.open
  const Icon = config.icon

  return (
    <Badge variant={config.variant} className={className}>
      <Icon className="mr-1 h-3 w-3" />
      {config.label}
    </Badge>
  )
}
