import { Head, Link } from '@inertiajs/react'
import { AppLayout } from '@/components/AppLayout'
import { Button } from '@/components/ui/button'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Badge } from '@/components/ui/badge'
import { Plus, FileText } from 'lucide-react'
import { formatDate } from '@/utils/formatting'
import { ReportTypeBadge } from '@/components/tax-reports/ReportTypeBadge'
import { MissingReportsAlert } from '@/components/tax-reports/MissingReportsAlert'
import { calculateMissingPeriods } from '@/utils/missing-reports'
import type { TaxReportSummary, Company } from '@/types/tax-reports'
import { useState, useMemo } from 'react'

interface TaxReportsIndexProps {
  company: Company
  taxReports: TaxReportSummary[]
  calendarYears: number[]
}

export default function Index({ company, taxReports, calendarYears }: TaxReportsIndexProps) {
  const currentYear = new Date().getFullYear()
  const [selectedYear, setSelectedYear] = useState<number>(currentYear)
  const [selectedReportType, setSelectedReportType] = useState<string>('all')

  // Filter reports by selected year and type
  const filteredReports = useMemo(() => {
    return taxReports.filter((report) => {
      const reportYear = new Date(report.startDate).getFullYear()
      const matchesYear = reportYear === selectedYear
      const matchesType = selectedReportType === 'all' || report.reportType === selectedReportType
      return matchesYear && matchesType
    })
  }, [taxReports, selectedYear, selectedReportType])

  // Calculate missing UStVA monthly reports
  const missingUstvaMonthly = useMemo(() => {
    return calculateMissingPeriods(selectedYear, 'ustva', 'monthly', taxReports)
  }, [selectedYear, taxReports])

  // Status badge component
  const StatusBadge = ({ status }: { status: string }) => {
    const variants = {
      draft: { variant: 'secondary' as const, label: 'Draft' },
      submitted: { variant: 'default' as const, label: 'Submitted' },
      accepted: { variant: 'outline' as const, label: 'Accepted' }
    }
    const config = variants[status as keyof typeof variants] || variants.draft
    return <Badge variant={config.variant}>{config.label}</Badge>
  }

  return (
    <AppLayout company={company} currentPage="tax-reports">
      <Head title="Tax Reports" />

      <div className="container mx-auto py-6 space-y-6">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold">Tax Reports</h1>
            <p className="text-muted-foreground">
              Manage your tax reports (UStVA, KSt, and more)
            </p>
          </div>
          <Link href="/tax_reports/new">
            <Button>
              <Plus className="w-4 h-4 mr-2" />
              Generate New Report
            </Button>
          </Link>
        </div>

        {/* Missing Reports Alert */}
        {missingUstvaMonthly.length > 0 && selectedReportType !== 'kst' && (
          <MissingReportsAlert
            calendarYear={selectedYear}
            reportType="ustva"
            periodType="monthly"
            missingPeriods={missingUstvaMonthly}
          />
        )}

        {/* Filters */}
        <Card>
          <CardHeader>
            <CardTitle>Filters</CardTitle>
            <CardDescription>Filter reports by year and type</CardDescription>
          </CardHeader>
          <CardContent className="flex gap-4">
            <div className="flex-1">
              <label className="text-sm font-medium mb-2 block">Calendar Year</label>
              <Select value={selectedYear.toString()} onValueChange={(v) => setSelectedYear(parseInt(v))}>
                <SelectTrigger>
                  <SelectValue placeholder="Select year" />
                </SelectTrigger>
                <SelectContent>
                  {calendarYears.map((year) => (
                    <SelectItem key={year} value={year.toString()}>
                      {year}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="flex-1">
              <label className="text-sm font-medium mb-2 block">Report Type</label>
              <Select value={selectedReportType} onValueChange={setSelectedReportType}>
                <SelectTrigger>
                  <SelectValue placeholder="All types" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Types</SelectItem>
                  <SelectItem value="ustva">UStVA</SelectItem>
                  <SelectItem value="kst">KSt</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </CardContent>
        </Card>

        {/* Reports Table */}
        <Card>
          <CardHeader>
            <CardTitle>Reports ({filteredReports.length})</CardTitle>
            <CardDescription>
              {selectedYear} - {selectedReportType === 'all' ? 'All types' : selectedReportType.toUpperCase()}
            </CardDescription>
          </CardHeader>
          <CardContent>
            {filteredReports.length === 0 ? (
              <div className="text-center py-12">
                <FileText className="w-12 h-12 mx-auto text-muted-foreground mb-4" />
                <h3 className="text-lg font-semibold mb-2">No reports found</h3>
                <p className="text-muted-foreground mb-4">
                  Generate your first tax report to get started.
                </p>
                <Link href="/tax_reports/new">
                  <Button>
                    <Plus className="w-4 h-4 mr-2" />
                    Generate Report
                  </Button>
                </Link>
              </div>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Period</TableHead>
                    <TableHead>Type</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Submitted</TableHead>
                    <TableHead className="text-right">Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredReports.map((report) => (
                    <TableRow key={report.id} className="cursor-pointer hover:bg-muted/50">
                      <TableCell>
                        <div className="font-medium">{report.periodLabel}</div>
                        <div className="text-sm text-muted-foreground">
                          {formatDate(report.startDate)} - {formatDate(report.endDate)}
                        </div>
                      </TableCell>
                      <TableCell>
                        <ReportTypeBadge reportType={report.reportType} />
                      </TableCell>
                      <TableCell>
                        <StatusBadge status={report.status} />
                      </TableCell>
                      <TableCell>
                        {report.submittedAt ? formatDate(report.submittedAt) : '-'}
                      </TableCell>
                      <TableCell className="text-right">
                        <Link href={`/tax_reports/${report.id}`}>
                          <Button variant="ghost" size="sm">
                            View
                          </Button>
                        </Link>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}
          </CardContent>
        </Card>
      </div>
    </AppLayout>
  )
}
