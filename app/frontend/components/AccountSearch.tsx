import { useState, useEffect } from 'react'
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from '@/components/ui/command'
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from '@/components/ui/popover'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Check, ChevronsUpDown } from 'lucide-react'
import { cn } from '@/lib/utils'

interface Account {
  id: number
  code: string
  name: string
  accountType: string
  taxRate: number
}

interface AccountSearchProps {
  recentAccounts: Account[]
  selectedAccount: Account | null
  onSelect: (account: Account | null) => void
}

export function AccountSearch({
  recentAccounts,
  selectedAccount,
  onSelect,
}: AccountSearchProps) {
  const [open, setOpen] = useState(false)
  const [search, setSearch] = useState('')
  const [searchResults, setSearchResults] = useState<Account[]>([])
  const [isSearching, setIsSearching] = useState(false)

  useEffect(() => {
    if (search.length < 2) {
      setSearchResults([])
      return
    }

    const timeoutId = setTimeout(async () => {
      setIsSearching(true)
      try {
        const response = await fetch(`/accounts?search=${encodeURIComponent(search)}`)
        const data = await response.json()
        setSearchResults(data.accounts)
      } catch (err) {
        console.error('Failed to search accounts', err)
      } finally {
        setIsSearching(false)
      }
    }, 300)

    return () => clearTimeout(timeoutId)
  }, [search])

  const accountTypeLabel = (type: string) => {
    const labels: Record<string, string> = {
      asset: 'Asset',
      liability: 'Liability',
      equity: 'Equity',
      revenue: 'Revenue',
      expense: 'Expense',
    }
    return labels[type] || type
  }

  const accountTypeBadgeVariant = (type: string): 'default' | 'secondary' | 'outline' => {
    if (type === 'expense') return 'default'
    if (type === 'revenue') return 'secondary'
    return 'outline'
  }

  const displayAccounts = search.length >= 2 ? searchResults : recentAccounts

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button
          variant="outline"
          role="combobox"
          aria-expanded={open}
          className="w-full justify-between font-normal"
        >
          {selectedAccount ? (
            <span>
              <span className="font-mono">{selectedAccount.code}</span>
              {' '}
              {selectedAccount.name}
            </span>
          ) : (
            <span className="text-muted-foreground">Select account...</span>
          )}
          <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
        </Button>
      </PopoverTrigger>
      <PopoverContent className="w-[400px] p-0" align="start">
        <Command shouldFilter={false}>
          <CommandInput
            placeholder="Search by code or name..."
            value={search}
            onValueChange={setSearch}
          />
          <CommandList>
            <CommandEmpty>
              {isSearching ? 'Searching...' : search.length < 2 && recentAccounts.length === 0 ? 'Start typing to search...' : 'No accounts found.'}
            </CommandEmpty>
            {search.length < 2 && recentAccounts.length > 0 && (
              <CommandGroup heading="Recently Used">
                {recentAccounts.map((account) => (
                  <CommandItem
                    key={account.id}
                    value={account.id.toString()}
                    onSelect={() => {
                      onSelect(account)
                      setOpen(false)
                    }}
                  >
                    <Check
                      className={cn(
                        'mr-2 h-4 w-4',
                        selectedAccount?.id === account.id ? 'opacity-100' : 'opacity-0'
                      )}
                    />
                    <span className="font-mono mr-2">{account.code}</span>
                    <span className="flex-1 truncate">{account.name}</span>
                    <Badge variant={accountTypeBadgeVariant(account.accountType)} className="ml-2">
                      {accountTypeLabel(account.accountType)}
                    </Badge>
                  </CommandItem>
                ))}
              </CommandGroup>
            )}
            {search.length >= 2 && searchResults.length > 0 && (
              <CommandGroup heading="Search Results">
                {searchResults.map((account) => (
                  <CommandItem
                    key={account.id}
                    value={account.id.toString()}
                    onSelect={() => {
                      onSelect(account)
                      setOpen(false)
                    }}
                  >
                    <Check
                      className={cn(
                        'mr-2 h-4 w-4',
                        selectedAccount?.id === account.id ? 'opacity-100' : 'opacity-0'
                      )}
                    />
                    <span className="font-mono mr-2">{account.code}</span>
                    <span className="flex-1 truncate">{account.name}</span>
                    <Badge variant={accountTypeBadgeVariant(account.accountType)} className="ml-2">
                      {accountTypeLabel(account.accountType)}
                    </Badge>
                  </CommandItem>
                ))}
              </CommandGroup>
            )}
          </CommandList>
        </Command>
      </PopoverContent>
    </Popover>
  )
}
