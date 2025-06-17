IMAGES := $(patsubst %/,%,$(sort $(dir $(wildcard */*))))
DIRECTORIES := $(foreach dir,$(subst /,_,$(patsubst %/,%,$(sort $(dir $(wildcard */*/))))),$(dir).erofs)

# Build all images
all: $(IMAGES)

# Build the erofs image
%.erofs:
	$(eval $@_SOURCE := $(subst _,/,$(subst .erofs,,$@)))
	@echo "Making $@ with source $($@_SOURCE)"
	mkfs.erofs $@ $($@_SOURCE)

# Build all images related to service
$(IMAGES): % : $(foreach type,conf sys service,$(filter %_$(type).erofs, $(DIRECTORIES)))

# Install prerequisites
preqreqs:
	apt install -y erofs-utils

# Clean up generated files
clean:
	rm -f *.erofs